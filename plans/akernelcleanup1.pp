plan mypatch::kernelcleanup1(
  TargetSpec $targets,
) {
  $results = {}

  # 1) Check /boot disk space (pre)
  $results['boot_pre'] = run_command('df -h /boot', $targets)

  # 2) List available kernels (pre)
  $results['kernels_pre'] = run_command('rpm -qa kernel', $targets)

  # 3) Cleanup old kernel files based on OS major version per host
  $cleanup_command = "bash -lc 'os_major=$(awk -F= '/^VERSION_ID=/{gsub(/\"/,\"\",\$2); split(\$2,a,\"\.\"); print a[1]; exit}' /etc/os-release 2>/dev/null || rpm -q --queryformat \"%{VERSION}\" redhat-release 2>/dev/null || rpm -q --queryformat \"%{VERSION}\" centos-release 2>/dev/null); if [ \"$os_major\" = \"7\" ]; then /usr/bin/package-cleanup --oldkernels --count=1 -y; elif [ \"$os_major\" = \"8\" ]; then /usr/bin/dnf remove --oldinstallonly --setopt installonly_limit=2 kernel -y; else echo \"UNSUPPORTED_OS_MAJOR:$os_major\"; fi'"
  $results['cleanup'] = run_command($cleanup_command, $targets, '_catch_errors' => true)

  # 4) Pause for 15 seconds
  $results['sleep'] = run_command('sleep 15', $targets)

  # 5) Check /boot disk space (post)
  $results['boot_post'] = run_command('df -h /boot', $targets)

  # 6) List available kernels (post)
  $results['kernels_post'] = run_command('rpm -qa kernel', $targets)

  return $results
}
