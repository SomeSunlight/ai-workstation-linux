#!/usr/bin/env python3
"""Read-only network inventory for AIW Linux; explicit, disposable probe optional.

No second NemoClaw registry, no destructive recovery, no privileged Podman,
no credential export. Snapshots contain PRIVATE addresses: mode 0600.
"""
from __future__ import annotations

import argparse
import difflib
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone
from urllib.parse import urlsplit

SCHEMA = 1
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,62}$")


def run(*args: str, timeout: int = 12) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            args, capture_output=True, text=True, timeout=timeout, check=False
        )
        return result.returncode == 0, result.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return False, ""


def object_json(*args: str):
    ok, output = run(*args)
    if not ok:
        return None
    try:
        return json.loads(output)
    except ValueError:
        return None


def ipv4_list(host: str) -> list[str]:
    if not host or not re.fullmatch(r"[A-Za-z0-9.-]{1,253}", host):
        return []
    ok, data = run("getent", "ahostsv4", host, timeout=5)
    if not ok:
        return []
    found = set()
    for line in data.splitlines():
        part = line.split()
        try:
            address = ipaddress.ip_address(part[0])
            if address.version == 4:
                found.add(str(address))
        except (IndexError, ValueError):
            continue
    return sorted(found)


def upstream_inventory() -> dict[str, dict]:
    data = object_json("nemohermes", "list", "--json")
    if not isinstance(data, dict):
        return {}
    rows = data.get("sandboxes", [])
    if isinstance(rows, dict):
        rows = [{"name": key, **value} for key, value in rows.items()
                if isinstance(value, dict)]
    if not isinstance(rows, list):
        return {}
    result = {}
    for entry in rows:
        if not isinstance(entry, dict):
            continue
        name = entry.get("name")
        if not isinstance(name, str) or not NAME_RE.fullmatch(name):
            continue
        host = ""
        # This is only metadata published by upstream; do not read Hermes
        # secrets, full provider credential records, or raw JSON into snapshots.
        for key in ("endpointUrl", "inferenceEndpointUrl"):
            url = entry.get(key)
            if isinstance(url, str) and url.startswith(("https://", "http://")):
                try:
                    host = urlsplit(url).hostname or ""
                except ValueError:
                    pass
                break
        result[name] = {
            "provider": str(entry.get("provider") or ""),
            "model": str(entry.get("model") or ""),
            "endpoint_host": host,
        }
    return result


def host_network() -> dict:
    addresses = object_json("ip", "-j", "-4", "addr", "show")
    routes = object_json("ip", "-j", "-4", "route", "show", "default")
    fields = []
    if isinstance(addresses, list):
        for item in addresses:
            if not isinstance(item, dict):
                continue
            ips = []
            for a in item.get("addr_info", []):
                if a.get("family") == "inet" and a.get("local"):
                    ips.append(f"{a['local']}/{a.get('prefixlen', '?')}")
            if ips:
                fields.append({"interface": item.get("ifname", ""), "ipv4": sorted(ips)})
    defaults = []
    if isinstance(routes, list):
        for route in routes:
            if isinstance(route, dict) and route.get("dst") in ("default", None):
                defaults.append({
                    "gateway": route.get("gateway", ""),
                    "device": route.get("dev", ""),
                })
    return {"interfaces": fields, "default_routes": defaults}


def network_definition(name: str) -> dict:
    data = object_json("podman", "network", "inspect", name)
    if not isinstance(data, list) or not data or not isinstance(data[0], dict):
        return {"status": "unavailable"}
    net = data[0]
    return {
        "status": "configured",
        "name": str(net.get("name", name)),
        "subnets": [
            {"subnet": x.get("subnet", ""), "gateway": x.get("gateway", "")}
            for x in net.get("subnets", []) if isinstance(x, dict)
        ],
    }


def containers_for(name: str) -> list[str]:
    ok, stdout = run("podman", "ps", "-a", "--format", "{{.Names}}")
    if not ok:
        return []
    # Match the OpenShell-generated container ID suffix exactly; never
    # choose a different sandbox by substring or by apparent freshness.
    pattern = re.compile(
        r"^openshell-[A-Za-z0-9_-]+--" + re.escape(name)
        + r"-[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"
    )
    return [x for x in stdout.splitlines() if pattern.fullmatch(x.strip())]


def podman_container(name: str) -> tuple[dict, str]:
    names = containers_for(name)
    if len(names) != 1:
        return ({"status": "not found" if not names else "ambiguous",
                 "count": len(names)}, "")
    data = object_json("podman", "inspect", names[0])
    if not isinstance(data, list) or len(data) != 1:
        return {"status": "inspect unavailable"}, ""
    record = data[0]
    if not isinstance(record, dict):
        return {"status": "inspect unavailable"}, ""
    hc = record.get("HostConfig") or {}
    st = record.get("State") or {}
    extra = {}
    for part in hc.get("ExtraHosts") or []:
        if not isinstance(part, str) or ":" not in part:
            continue
        host, ip = part.split(":", 1)
        if host in ("host.containers.internal", "host.openshell.internal"):
            extra[host] = ip
    return {
        "status": st.get("Status", "unknown"),
        "exit_code": st.get("ExitCode"),
        "oom_killed": bool(st.get("OOMKilled", False)),
        "network_mode": hc.get("NetworkMode", ""),
        "host_aliases": extra,
    }, str(record.get("ImageName") or "")


def gateway_listener(port: int) -> str:
    ok, out = run("ss", "-ltn")
    if not ok:
        return "not checked"
    for line in out.splitlines():
        cols = line.split()
        if len(cols) >= 4 and cols[3].endswith(f":{port}"):
            return "listening (host only)"
    return "not observed"


def disposable_probe(image: str, network: str, old_ip: str, port: int) -> dict:
    if not image:
        return {"status": "no local sandbox image; skipped"}
    try:
        old_ip = str(ipaddress.ip_address(old_ip))
        if ipaddress.ip_address(old_ip).version != 4:
            raise ValueError("IPv4 required")
    except ValueError:
        old_ip = ""
    # This script is intentionally static. It runs in a newly created
    # container, with no bind mounts, private credentials or privileges.
    script = r"""
set +e
current=$(getent ahostsv4 host.containers.internal | awk 'NR==1 {print $1}')
printf 'ALIAS %s\n' "$current"
for addr in "$current" "$AIW_OLD_IP"; do
  [[ -n "$addr" ]] || continue
  if timeout 4 bash -c 'exec 3<>/dev/tcp/"$1"/"$2"' _ "$addr" "$AIW_GATEWAY_PORT" 2>/dev/null; then
    printf 'TCP %s OK\n' "$addr"
  else
    printf 'TCP %s FAIL\n' "$addr"
  fi
done
"""
    ok, out = run(
        "podman", "run", "--rm", "--pull=never",
        "--network", network, "--entrypoint", "/bin/bash",
        "--env", f"AIW_OLD_IP={old_ip}",
        "--env", f"AIW_GATEWAY_PORT={port}",
        image, "-lc", script, timeout=40,
    )
    if not ok:
        return {"status": "test container unavailable", "details": "no changes to Hermes"}
    result: dict = {"status": "tested", "resolved_host_gateway": "", "tcp": {}}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] == "ALIAS":
            result["resolved_host_gateway"] = parts[1]
        elif len(parts) == 3 and parts[0] == "TCP":
            result["tcp"][parts[1]] = parts[2]
    return result


def collect(names: list[str], inventory: dict, network: str, port: int, probe: bool) -> dict:
    snapshot: dict = {
        "schema_version": SCHEMA,
        "captured_utc": datetime.now(timezone.utc).isoformat(),
        "host": host_network(),
        "network": network_definition(network),
        "gateway_listener": {str(port): gateway_listener(port)},
        "sandboxes": {},
    }
    for name in names:
        container, image = podman_container(name)
        entry = inventory.get(name, {})
        host = entry.get("endpoint_host", "")
        sb = {
            "provider": entry.get("provider", ""),
            "model": entry.get("model", ""),
            "provider_endpoint_host": host,
            "provider_resolved_ips": ipv4_list(host),
            "podman": container,
        }
        if probe:
            mapping = container.get("host_aliases", {})
            old_ip = mapping.get("host.containers.internal", "")
            sb["disposable_probe"] = disposable_probe(image, network, old_ip, port)
        snapshot["sandboxes"][name] = sb
    return snapshot


def render(snapshot: dict) -> None:
    print("AIW Linux network inventory (read-only except explicit --probe)")
    print(f"Podman bridge: {snapshot['network'].get('name', '?')}")
    for row in snapshot["network"].get("subnets", []):
        print(f"  subnet={row['subnet']} bridge-gateway={row['gateway']}")
    for row in snapshot["host"]["interfaces"]:
        print(f"Host: {row['interface']} {', '.join(row['ipv4'])}")
    for row in snapshot["host"]["default_routes"]:
        print(f"Default route: {row['gateway']} via {row['device']}")
    for port, status in snapshot["gateway_listener"].items():
        print(f"Gateway TCP {port}: {status}; container reachability NOT established")
    if not snapshot["sandboxes"]:
        print("No registered sandbox inventory available; no lifecycle actions.")
    for name, sb in snapshot["sandboxes"].items():
        p = sb["podman"]
        print(f"Sandbox: {name} | {p['status']} | exit={p.get('exit_code', '?')}"
              f" | provider={sb['provider']} | model={sb['model']}")
        if sb["provider_endpoint_host"]:
            print("  Provider host:", sb["provider_endpoint_host"],
                  "DNS:", ",".join(sb["provider_resolved_ips"]) or "unresolved")
        for host, addr in p.get("host_aliases", {}).items():
            print(f"  Stored host alias: {host} => {addr}")
        if "disposable_probe" in sb:
            z = sb["disposable_probe"]
            print("  Disposable probe:", z["status"])
            if z.get("resolved_host_gateway"):
                print("  Fresh host gateway:", z["resolved_host_gateway"])
                for ip, result in z.get("tcp", {}).items():
                    print(f"    TCP {ip}: {result}")
        elif p.get("host_aliases"):
            print("  Current container-to-host path: NOT checked "
                  "(explicit --probe required)")
    print("Private network data: do not publish raw snapshots or hostnames.")


def safe_save(path: Path, data: dict) -> None:
    path = path.expanduser()
    # Refuse existing files and symlinks, and never write to source tree by default.
    payload = json.dumps(data, indent=2, sort_keys=True) + "\n"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as dest:
            dest.write(payload)
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    print(f"Private snapshot created (0600): {path}")


def comparable(data: dict) -> dict:
    return {key: value for key, value in data.items() if key != "captured_utc"}


def main() -> int:
    os.umask(0o077)
    parser = argparse.ArgumentParser(
        description="Compare observed AIW Linux/Podman/NemoClaw IPs; never repair.")
    parser.add_argument("--sandbox", help="Registered sandbox name")
    parser.add_argument("--network", default="openshell-docker")
    parser.add_argument("--gateway-port", type=int, default=8080)
    parser.add_argument("--save", type=Path,
                        help="Create private snapshot JSON (0600; refuse overwrite)")
    parser.add_argument("--compare", type=Path,
                        help="Compare current observation with an earlier saved JSON")
    parser.add_argument("--probe", action="store_true",
                        help="Explicitly start/remove a disposable Podman test container")
    args = parser.parse_args()
    if not 1 <= args.gateway_port <= 65535:
        parser.error("gateway port must be in 1..65535")
    if args.sandbox is not None and not NAME_RE.fullmatch(args.sandbox):
        parser.error("invalid sandbox name")
    if not NAME_RE.fullmatch(args.network):
        parser.error("invalid Podman network name")
    inv = upstream_inventory()
    if args.sandbox and args.sandbox not in inv:
        print(f"[WARN] {args.sandbox} is not in the current NemoClaw list; "
              "read-only Podman inspect will still be attempted.", file=sys.stderr)
    names = [args.sandbox] if args.sandbox else sorted(inv)[:20]
    snapshot = collect(names, inv, args.network, args.gateway_port, args.probe)
    render(snapshot)
    if args.save:
        try:
            safe_save(args.save, snapshot)
        except OSError as exc:
            print(f"[STOP] Snapshot not written: {exc}", file=sys.stderr)
            return 2
    if args.compare:
        try:
            previous = json.loads(args.compare.expanduser().read_text(encoding="utf-8"))
            if not isinstance(previous, dict) or previous.get("schema_version") != SCHEMA:
                raise ValueError("snapshot schema mismatch")
        except (OSError, ValueError) as exc:
            print(f"[STOP] Cannot read prior snapshot: {exc}", file=sys.stderr)
            return 2
        before = json.dumps(comparable(previous), sort_keys=True, indent=2).splitlines()
        after = json.dumps(comparable(snapshot), sort_keys=True, indent=2).splitlines()
        change = list(difflib.unified_diff(before, after, fromfile="before", tofile="now"))
        print("\n".join(change) if change else "[OK] No differences in recorded network data.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
