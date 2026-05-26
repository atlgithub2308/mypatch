#!/bin/bash
set -euo pipefail

# Kernel cleanup task converted from Ansible playbook
# Performs checks and runs cleanup depending on OS major version

boot_pre=$(df -h /boot 2>&1 || true)
kernels_pre=$(rpm -qa kernel 2>&1 || true)

# Determine OS major version
os_major=""
if [ -f /etc/os-release ]; then
  os_major=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2); split($2,a,"."); print a[1]; exit}' /etc/os-release || true)
fi
if [ -z "$os_major" ]; then
  if rpm -q --qf '%{VERSION}' redhat-release >/dev/null 2>&1; then
    os_major=$(rpm -q --qf '%{VERSION}' redhat-release 2>/dev/null || true)
  elif rpm -q --qf '%{VERSION}' centos-release >/dev/null 2>&1; then
    os_major=$(rpm -q --qf '%{VERSION}' centos-release 2>/dev/null || true)
  fi
fi

cleanup_cmd=""
cleanup_stdout=""
cleanup_stderr=""
cleanup_rc=0
if [ "$os_major" = "7" ]; then
  cleanup_cmd="/usr/bin/package-cleanup --oldkernels --count=1 -y"
  if command -v package-cleanup >/dev/null 2>&1; then
    # capture stdout/stderr separately
    cleanup_stdout=$(mktemp)
    cleanup_stderr=$(mktemp)
    if ! /usr/bin/package-cleanup --oldkernels --count=1 -y >"$cleanup_stdout" 2>"$cleanup_stderr"; then
      cleanup_rc=$?
    fi
    cleanup_stdout=$(cat "$cleanup_stdout" || true)
    cleanup_stderr=$(cat "$cleanup_stderr" || true)
  else
    cleanup_stderr="package-cleanup not found"
    cleanup_rc=127
  fi
elif [ "$os_major" = "8" ]; then
  cleanup_cmd="/usr/bin/dnf remove --oldinstallonly --setopt installonly_limit=2 kernel -y"
  if command -v dnf >/dev/null 2>&1; then
    cleanup_stdout=$(mktemp)
    cleanup_stderr=$(mktemp)
    if ! /usr/bin/dnf remove --oldinstallonly --setopt installonly_limit=2 kernel -y >"$cleanup_stdout" 2>"$cleanup_stderr"; then
      cleanup_rc=$?
    fi
    cleanup_stdout=$(cat "$cleanup_stdout" || true)
    cleanup_stderr=$(cat "$cleanup_stderr" || true)
  else
    cleanup_stderr="dnf not found"
    cleanup_rc=127
  fi
else
  cleanup_cmd=""
  cleanup_stderr="Unsupported OS major: ${os_major}"
  cleanup_rc=0
fi

# Wait like the Ansible playbook
sleep 15

boot_post=$(df -h /boot 2>&1 || true)
kernels_post=$(rpm -qa kernel 2>&1 || true)

# Emit JSON output (Puppet tasks expect JSON on stdout)
cat <<JSON
{
  "boot_pre": "$(echo "$boot_pre" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')",
  "kernels_pre": "$(echo "$kernels_pre" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')",
  "os_major": "${os_major}",
  "cleanup_cmd": "${cleanup_cmd}",
  "cleanup_stdout": "$(echo "$cleanup_stdout" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')",
  "cleanup_stderr": "$(echo "$cleanup_stderr" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')",
  "cleanup_rc": ${cleanup_rc},
  "boot_post": "$(echo "$boot_post" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')",
  "kernels_post": "$(echo "$kernels_post" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')"
}
JSON

exit 0
