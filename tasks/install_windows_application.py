#!/usr/bin/env python3

import json
import os
import subprocess
import sys


def read_parameters():
    try:
        input_data = sys.stdin.read()
        if not input_data:
            return {}
        return json.loads(input_data)
    except json.JSONDecodeError as exc:
        print(json.dumps({
            "success": False,
            "message": f"Failed to parse JSON input: {exc}",
            "stdout": "",
            "stderr": "",
        }))
        sys.exit(1)


def build_choco_command(application, version=None):
    command = ["choco", "install", application, "-y", "--no-progress"]
    if version:
        command.extend(["--version", version])
    return command


def normalize_text(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8", errors="replace")
        except Exception:
            return str(value)
    return str(value)


def main():
    params = read_parameters()
    application = params.get("application")
    version = params.get("version")

    if not application:
        print(json.dumps({
            "success": False,
            "message": "The 'application' parameter is required.",
            "application": application,
            "version": version,
            "stdout": "",
            "stderr": "",
        }))
        sys.exit(1)

    command = build_choco_command(application, version)

    try:
        process = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError:
        print(json.dumps({
            "success": False,
            "message": "Chocolatey executable 'choco' was not found in the PATH.",
            "application": application,
            "version": version,
            "stdout": "",
            "stderr": "",
            "command": command,
        }))
        sys.exit(1)
    except Exception as exc:
        print(json.dumps({
            "success": False,
            "message": f"Failed to execute Chocolatey: {exc}",
            "application": application,
            "version": version,
            "stdout": "",
            "stderr": "",
            "command": command,
        }))
        sys.exit(1)

    stdout = normalize_text(process.stdout)
    stderr = normalize_text(process.stderr)
    success = process.returncode == 0
    message = (
        "Chocolatey package installed successfully."
        if success
        else f"Chocolatey install failed with exit code {process.returncode}."
    )

    print(json.dumps({
        "success": success,
        "message": message,
        "application": application,
        "version": version,
        "exit_code": process.returncode,
        "stdout": stdout,
        "stderr": stderr,
        "command": command,
    }))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
