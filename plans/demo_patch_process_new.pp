# @summary Executes the demo patch process with email, approval, service stops, snapshotting, and patching.
#
# This plan orchestrates a complete patching workflow across Rocky Linux and Windows nodes
# including pre-patch notifications, approval gates, service management, and package updates.
#
# @param $targets
#   Target set for common operations (string or array of strings).
# @param $rocky_target
#   The Rocky Linux target (default: sgdemorocky3.atl88.online).
# @param $windows_target
#   The Windows target (default: sgdemowin2.atl88.online).
# @param String[1] $notification_subject
#   Subject line for notification email.
# @param String[1] $notification_message
#   Message body for notification email.
# @param String[1] $vmname
#   VM name to snapshot.
# @param String[1] $snapshotname
#   Snapshot name to create.
# @param String[1] $package_name
#   Linux package to patch.
# @param String[1] $windows_package
#   Windows package to patch.
# @param Boolean $noop
#   Run in simulation mode (default: false).
#
# @return Hash
#   Result hash with status and message.
#
plan mypatch::demo_patch_process_new(
  $targets,
  $rocky_target   = 'sgdemorocky3.atl88.online',
  $windows_target = 'sgdemowin2.atl88.online',
  String[1] $notification_subject,
  String[1] $notification_message,
  String[1] $vmname,
  String[1] $snapshotname,
  String[1] $package_name,
  String[1] $windows_package,
  Boolean $noop = false,
) {
  # Hardcoded values
  $recipient_email = 'angteckleong@gmail.com'
  $gcp_project = 'atldemo'
  $gcp_zone = 'asia-southeast1-a'

  # Step 1: Send email notification
  out::message("Step 1: Sending email notification to ${recipient_email}...")
  run_task('mypatch::demo_send_email_notification', $targets, {
      email   => $recipient_email,
      subject => $notification_subject,
      message => $notification_message,
      noop    => $noop,
  })

  # Step 2: Wait for approval
  out::message('Step 2: Waiting for approval...')
  $approval_result = run_task('mypatch::demo_await_approval', $targets, {
      noop => $noop,
  })
  $approval_data = $approval_result.first.value
  if $approval_data['approved'] != true {
    fail("Approval denied: ${approval_data['message']}")
  }
  out::message("Approval received: ${approval_data['message']}")

  # Step 3: Stop httpd on Rocky Linux
  out::message("Step 3: Stopping httpd on ${rocky_target}...")
  run_task('mypatch::demo_stop_httpd', $rocky_target, {
      noop => $noop,
  })

  # Step 4: Stop MSSQL on Windows
  out::message("Step 4: Stopping MSSQL on ${windows_target}...")
  run_task('mypatch::demo_stop_mssql', $windows_target, {
      noop => $noop,
  })

  # Step 5: Create GCP snapshot
  out::message("Step 5: Creating snapshot ${snapshotname} for VM ${vmname}...")
  run_task('mypatch::demo_create_gcp_snapshot', $targets, {
      project      => $gcp_project,
      zone         => $gcp_zone,
      vmname       => $vmname,
      snapshotname => $snapshotname,
      noop         => $noop,
  })

  # Step 6: Patch Linux package
  out::message("Step 6: Patching package ${package_name} on ${rocky_target}...")
  run_task('mypatch::demo_patch_linux', $rocky_target, {
      package => $package_name,
      noop    => $noop,
  })

  # Step 7: Patch Windows package
  out::message("Step 7: Patching package ${windows_package} on ${windows_target}...")
  run_task('mypatch::demo_patch_windows', $windows_target, {
      package => $windows_package,
      noop    => $noop,
  })

  out::message('Demo patch process completed successfully.')

  return ({
      status  => 'success',
      message => 'demo_patch_process_new completed',
  })
}
