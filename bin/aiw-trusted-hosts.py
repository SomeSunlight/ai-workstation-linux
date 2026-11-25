#!/usr/bin/env python3
"""Local operator consent only; no endpoint discovery or vendor state."""
import os
import re
import stat
import sys
from pathlib import Path

KEY = "NEMOCLAW_TRUSTED_PRIVATE_HOSTS"
LABEL = re.compile(r"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?", re.ASCII)

def validated(value):
    if not value:
        return ""
    hosts = value.split(",")
    for host in hosts:
        labels = host.split(".")
        if (len(host) > 253 or len(labels) < 2
                or not all(LABEL.fullmatch(label) for label in labels)
                or not re.search(r"[a-zA-Z]", labels[-1])
                or re.fullmatch(r"0[xX][0-9a-fA-F]+", labels[-1])):
            raise ValueError("Expected exact DNS hostnames, comma-separated.")
    return ",".join(dict.fromkeys(host.lower() for host in hosts))

def directory(create=False):
    home = Path.home()
    if home.resolve() != home or not home.is_dir():
        raise ValueError("Unsafe home directory.")
    path = home / ".aiw-private-inference"
    if create:
        try:
            path.mkdir(mode=0o700)
        except FileExistsError:
            pass
    try:
        fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except FileNotFoundError:
        return None
    info = os.fstat(fd)
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        os.close(fd)
        raise ValueError("Unsafe private inference configuration directory.")
    return fd

def load(fd):
    if fd is None:
        return ""
    try:
        file = os.open("hosts", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
    except FileNotFoundError:
        return ""
    with os.fdopen(file, "rb") as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
                or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1):
            raise ValueError("Unsafe private inference configuration file.")
        raw = stream.read(8193)
        if len(raw) > 8192:
            raise ValueError("Private inference configuration too large.")
        return validated(raw.decode("ascii").removesuffix("\n"))

def save(fd, value):
    import secrets
    name = ".hosts-" + secrets.token_hex(16)
    file = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                   0o600, dir_fd=fd)
    try:
        with os.fdopen(file, "w", encoding="ascii") as stream:
            stream.write(value + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, "hosts", src_dir_fd=fd, dst_dir_fd=fd)
    finally:
        try:
            os.unlink(name, dir_fd=fd)
        except FileNotFoundError:
            pass

def main():
    action = sys.argv[1]
    fd = directory()
    try:
        stored = load(fd)
        if action == "effective":
            # Explicit environment is a one-shot replacement, even if empty.
            print(validated(os.environ[KEY]) if KEY in os.environ else stored)
            return
        if action != "configure":
            raise ValueError("Unknown action.")
        print("Private DNS may resolve an inference hostname to a private IP.")
        print("Trust only exact DNS hostnames you control and explicitly approve.")
        print("This exception applies to AIW onboarding, not sandbox policies.")
        print("Saved hosts: " + (stored or "(none)"))
        if KEY in os.environ:
            print("An explicit environment override takes precedence for this shell.")
        answer = input("Replace list (comma-separated), '-' to remove, Enter to keep: ")
        if not answer:
            return
        value = validated("" if answer == "-" else answer)
        print("New saved hosts: " + (value or "(none)"))
        if input("Confirm this exact list [y/N]: ") != "y":
            print("No changes made.")
            return
        if fd is None:
            fd = directory(create=True)
        save(fd, value)
    finally:
        if fd is not None:
            os.close(fd)

if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, EOFError, UnicodeError):
        print("[BLOCKED] Invalid or unsafe private inference host configuration. "
              "Review exact DNS names and local file permissions.", file=sys.stderr)
        sys.exit(1)
