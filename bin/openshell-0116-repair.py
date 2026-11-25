#!/usr/bin/env python3
"""Temporary offline phase repair; OpenShell 0.0.116 only (issue #11)."""
import argparse
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import time
import uuid

UNIT = "nemoclaw-openshell-gateway.service"


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def require(ok, message):
    if not ok:
        raise ValueError(message)


def varint(data, pos):
    value = 0
    for shift in range(0, 70, 7):
        require(pos < len(data), "Truncated protobuf")
        byte = data[pos]
        pos += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, pos
    raise ValueError("Invalid varint")


def fields(data):
    """Yield field number, wire type, value start, end and decoded value."""
    pos = 0
    while pos < len(data):
        tag, pos = varint(data, pos)
        number, wire = tag >> 3, tag & 7
        require(number > 0, "Invalid field number")
        if wire == 0:
            start = pos
            value, pos = varint(data, pos)
        elif wire == 2:
            size, pos = varint(data, pos)
            start = pos
            pos += size
            value = data[start:pos]
        elif wire in (1, 5):
            start = pos
            pos += 8 if wire == 1 else 4
            value = data[start:pos]
        else:
            raise ValueError("Unsupported protobuf wire type")
        require(pos <= len(data), "Truncated field")
        yield number, wire, start, pos, value


def one(data, number, wire):
    matches = [f for f in fields(data) if f[0] == number]
    require(len(matches) == 1 and matches[0][1] == wire,
            f"Unexpected protobuf field {number}")
    return matches[0]


def repair(payload, name, identity):
    meta = one(payload, 1, 2)[4]
    require(one(meta, 1, 2)[4] == identity.encode(), "UUID mismatch")
    require(one(meta, 2, 2)[4] == name.encode(), "Name mismatch")
    require(not any(f[0] == 8 and f[4] for f in fields(meta)),
            "Sandbox is being deleted")
    status = one(payload, 3, 2)
    phase = one(status[4], 6, 0)
    require(phase[4] == 3 and phase[3] - phase[2] == 1, "Not canonical Error")
    exits = [f for f in fields(status[4]) if f[0] == 9]
    require(len(exits) <= 1 and all(f[1] == 0 for f in exits),
            "Unexpected exit-code encoding")
    reasons = []
    for f in fields(status[4]):
        if f[0] == 5 and f[1] == 2:
            reasons.append(tuple(one(f[4], n, 2)[4] for n in (1, 2, 3)))
    # OpenShell v0.0.116 compute/mod.rs write_lifecycle_phase clears exit_code
    # on Starting and retains the previous instance ID as a tombstone.
    # Preserve both here; let the native start perform that transition.
    expected = b"MainProcessExited" if exits else b"ContainerExited"
    require((b"Ready", b"False", expected) in reasons,
            "No matching lifecycle condition: " + repr(reasons))
    if exits:
        print(f"Recorded main-process exit: {exits[0][4]}; native start clears it.")
    offset = status[2] + phase[2]
    return payload[:offset] + b"\x07" + payload[offset+1:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name")
    parser.add_argument("uuid")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    name, identity = args.name, str(uuid.UUID(args.uuid))
    require(re.fullmatch(r"[a-z][a-z0-9-]{0,18}", name), "Invalid name")
    require(os.getuid() != 0, "Run as the rootless Podman owner")
    require(not any(os.environ.get(k) for k in
                    ("DOCKER_HOST", "DOCKER_CONTEXT", "CONTAINER_HOST", "CONTAINER_CONNECTION")),
            "Redirected container environment")
    require(run("openshell", "--version") == "openshell 0.0.116",
            "Only OpenShell 0.0.116 is supported")
    # The operator must verify the database path from the active service first.
    db = Path.home() / ".local/state/nemoclaw/openshell-docker-gateway/openshell.db"
    require(db.is_file(), "Expected gateway database absent")
    require(not run("podman", "ps", "--filter", "name=openshell-", "--format", "{{.Names}}"),
            "Stop all running OpenShell sandbox containers first using native commands")
    container = json.loads(run("podman", "inspect",
                               f"openshell-default--{name}-{identity}"))[0]
    require(container["State"]["Status"] == "exited", "Container not exited")
    mounts = {m["Destination"]: m for m in container["Mounts"]}
    for dest, volume in (("/sandbox", f"openshell-sandbox-{identity}-workspace"),
                         ("/sandbox/.hermes", f"nemoclaw-hermes-state-v1-{name}")):
        require(mounts.get(dest, {}).get("Name") == volume, "Volume mapping mismatch")
        run("podman", "volume", "inspect", volume)
    if args.apply:
        require(run("systemctl", "--user", "show", UNIT, "-p", "ActiveState", "--value")
                == "inactive", "Stop the shared gateway first")
        require(run("systemctl", "--user", "show", UNIT, "-p", "MainPID", "--value")
                == "0", "Gateway process still active")
    mode = "rw" if args.apply else "ro"
    with sqlite3.connect(db.as_uri() + "?mode=" + mode, uri=True) as conn:
        if args.apply:
            conn.execute("BEGIN IMMEDIATE")
        row = conn.execute(
            "SELECT payload,resource_version FROM objects WHERE object_type='sandbox' "
            "AND id=? AND name=? AND workspace='default'", (identity, name)).fetchone()
        require(row is not None, "Sandbox row not found")
        old, version = row
        new = repair(old, name, identity)
        if args.apply:
            require(input(f"Type {name} to repair the selected row without backup: ") == name,
                    "Cancelled")
            result = conn.execute(
                "UPDATE objects SET payload=?,resource_version=resource_version+1,updated_at_ms=? "
                "WHERE object_type='sandbox' AND id=? AND name=? AND workspace='default' "
                "AND resource_version=? AND payload=?",
                (new, time.time_ns() // 1_000_000, identity, name, version, old))
            require(result.rowcount == 1, "Concurrent change; no repair")
        print("Phase changed to Stopped." if args.apply else
              "Dry run: eligible for phase-only repair; no change.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, sqlite3.Error, subprocess.CalledProcessError,
            KeyError, IndexError, EOFError) as exc:
        raise SystemExit(f"[BLOCKED] {exc}")
