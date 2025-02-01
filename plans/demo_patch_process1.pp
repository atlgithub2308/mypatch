plan mypatch::demo_patch_process(
  TargetSpec $targets,
  String $recipient_email,
  String $notification_subject,
  String $notification_message,
) {
  # Step 1: Send an email notification
  out::message("Sending email notification to $recipient_email...")
  $email_task_result = run_task('mypatch::demo_send_email_notification', $targets, {
    'email'   => $recipient_email,
    'subject' => $notification_subject,
    'message' => $notification_message,
  })

  # Process the result of the email task
  if $email_task_result.ok {
    out::message("Email sent successfully.")
  } else {
    fail("Failed to send email notification: ${email_task_result[0].error.message}")
  }

  # Step 2: Wait for approval email
  out::message("Waiting for approval email...")
  $approval_task_result = run_task('mypatch::demo_await_approval', $targets)

  # Process the result of the approval task
  $approval_data = $approval_task_result[0].value # Get the first target's result
  if $approval_task_result.ok and $approval_data['approved'] {
    out::message("Approval received: ${approval_data['message']}")
  } else {
    fail("Approval not received: ${approval_data['message']}")
  }

  # Step 3: Stop httpd service on sgdemorocky2.atl88.online
  out::message("Stopping httpd service on sgdemorocky3.atl88.online...")
  $httpd_task_result = run_task('mypatch::demo_stop_httpd', 'sgdemorocky3.atl88.online')

  # Process the result of the httpd stop task
  if $httpd_task_result.ok {
    out::message("httpd service stopped successfully on sgdemorocky3.atl88.online.")
  } else {
    fail("Failed to stop httpd service: ${httpd_task_result[0].error.message}")
  }

  # Step 4: Stop MSSQL service on sgdemowin2.atl88.online
  out::message("Stopping MSSQL service on sgdemowin2.atl88.online...")
  $mssql_task_result = run_task('mypatch::demo_stop_mssql', 'sgdemowin2.atl88.online')

  # Process the result of the MSSQL stop task
  if $mssql_task_result.ok {
    out::message("MSSQL service stopped successfully on sgdemowin2.atl88.online.")
  } else {
    fail("Failed to stop MSSQL service: ${mssql_task_result[0].error.message}")
  }
}
