#!/usr/bin/env python3

import json
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
            "action": "",
            "application": "",
            "version": "",
            "stdout": "",
            "stderr": "",
        }))
        sys.exit(1)


def normalize_text(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8", errors="replace")
        except Exception:
            return str(value)
    return str(value)


def run_choco_command(command_args):
    try:
        process = subprocess.run(
            command_args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        return {
            "stdout": normalize_text(process.stdout),
            "stderr": normalize_text(process.stderr),
            "exit_code": process.returncode,
            "command": " ".join(command_args),
        }
    except FileNotFoundError:
        return {
            "stdout": "",
            "stderr": "Chocolatey executable 'choco' was not found in the PATH.",
            "exit_code": 1,
            "command": " ".join(command_args),
            "error": "choco_not_found",
        }
    except Exception as exc:
        return {
            "stdout": "",
            "stderr": f"Failed to execute Chocolatey: {exc}",
            "exit_code": 1,
            "command": " ".join(command_args),
            "error": "execution_failed",
        }


def action_list():
    command = ["choco", "list"]
    result = run_choco_command(command)
    
    if result["exit_code"] == 0:
        # Parse the output to extract package names and versions
        packages = []
        for line in result["stdout"].split("\n"):
            line = line.strip()
            if not line or "packages installed" in line:
                continue
            parts = line.split(None, 1)
            if len(parts) >= 2:
                packages.append({"name": parts[0], "version": parts[1]})
        
        return {
            "success": True,
            "message": "Chocolatey packages listed successfully.",
            "action": "list",
            "application": "",
            "version": "",
            "exit_code": result["exit_code"],
            "stdout": result["stdout"],
            "stderr": result["stderr"],
            "command": result["command"],
            "data": packages,
        }
    else:
        return {
            "success": False,
            "message": f"Chocolatey list failed with exit code {result['exit_code']}.",
            "action": "list",
            "application": "",
            "version": "",
            "exit_code": result["exit_code"],
            "stdout": result["stdout"],
            "stderr": result["stderr"],
            "command": result["command"],
        }


def action_install(application, version=None):
    if not application:
        return {
            "success": False,
            "message": "The 'application' parameter is required for install action.",
            "action": "install",
            "application": "",
            "version": "",
            "exit_code": 1,
            "stdout": "",
            "stderr": "",
            "command": "",
        }
    
    command = ["choco", "install", application, "-y", "--no-progress"]
    if version:
        command.extend(["--version", version])
    
    result = run_choco_command(command)
    success = result["exit_code"] == 0
    
    return {
        "success": success,
        "message": (
            "Chocolatey package installed successfully."
            if success
            else f"Chocolatey install failed with exit code {result['exit_code']}."
        ),
        "action": "install",
        "application": application,
        "version": version or "",
        "exit_code": result["exit_code"],
        "stdout": result["stdout"],
        "stderr": result["stderr"],
        "command": result["command"],
    }


def action_uninstall(application):
    if not application:
        return {
            "success": False,
            "message": "The 'application' parameter is required for uninstall action.",
            "action": "uninstall",
            "application": "",
            "version": "",
            "exit_code": 1,
            "stdout": "",
            "stderr": "",
            "command": "",
        }
    
    command = ["choco", "uninstall", application, "-y", "--no-progress"]
    result = run_choco_command(command)
    success = result["exit_code"] == 0
    
    return {
        "success": success,
        "message": (
            "Chocolatey package uninstalled successfully."
            if success
            else f"Chocolatey uninstall failed with exit code {result['exit_code']}."
        ),
        "action": "uninstall",
        "application": application,
        "version": "",
        "exit_code": result["exit_code"],
        "stdout": result["stdout"],
        "stderr": result["stderr"],
        "command": result["command"],
    }


def action_check_update(application, check_pinned=False):
    if not application:
        return {
            "success": False,
            "message": "The 'application' parameter is required for check-update action.",
            "action": "check-update",
            "application": "",
            "version": "",
            "exit_code": 1,
            "stdout": "",
            "stderr": "",
            "command": "",
        }
    
    command = ["choco", "outdated", application]
    if not check_pinned:
        command.append("--ignore-pinned")
    
    result = run_choco_command(command)
    success = result["exit_code"] == 0
    
    update_info = None
    if success:
        # Parse the output to extract version information
        # Output format: package_name|current_version|available_version|pinned?
        for line in result["stdout"].split("\n"):
            line = line.strip()
            if not line or "packages" in line:
                continue
            parts = line.split("|")
            if len(parts) >= 3:
                update_info = {
                    "name": parts[0].strip(),
                    "current_version": parts[1].strip(),
                    "available_version": parts[2].strip(),
                    "pinned": parts[3].strip() if len(parts) >= 4 else "False",
                }
                break
    
    output = {
        "success": success,
        "message": (
            "Update available for application." if (success and update_info)
            else "No updates available for application." if (success and not update_info)
            else f"Chocolatey check-update failed with exit code {result['exit_code']}."
        ),
        "action": "check-update",
        "application": application,
        "version": "",
        "exit_code": result["exit_code"],
        "stdout": result["stdout"],
        "stderr": result["stderr"],
        "command": result["command"],
    }
    
    if update_info:
        output["data"] = update_info
    
    return output


def main():
    params = read_parameters()
    action = params.get("action")
    application = params.get("application")
    version = params.get("version")
    check_pinned = params.get("check_pinned", False)

    if not action:
        result = {
            "success": False,
            "message": "The 'action' parameter is required.",
            "action": "",
            "application": "",
            "version": "",
            "exit_code": 1,
            "stdout": "",
            "stderr": "",
            "command": "",
        }
    elif action == "list":
        result = action_list()
    elif action == "install":
        result = action_install(application, version)
    elif action == "uninstall":
        result = action_uninstall(application)
    elif action == "check-update":
        result = action_check_update(application, check_pinned)
    else:
        result = {
            "success": False,
            "message": f"Unknown action '{action}'. Supported actions: install, uninstall, list, check-update.",
            "action": action,
            "application": application,
            "version": version,
            "exit_code": 1,
            "stdout": "",
            "stderr": "",
            "command": "",
        }

    print(json.dumps(result))
    sys.exit(0 if result["success"] else 1)


if __name__ == "__main__":
    main()
