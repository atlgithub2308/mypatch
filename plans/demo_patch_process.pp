plan mypatch::demo_patch_process(
  TargetSpec $targets,
  String $recipient_email,
  String $notification_subject,
  String $notification_message,
) {
  # Step 1: Send an email notification
  out::message("Sending email notification to $recipient_email...")
  $email_task_result = run_task('mypatch::send_email_notification', $targets, {
    'email'   => $recipient_email,
    'subject' => $notification_subject,
    'message' => $notification_message,
  })
  
  # Check the result of the email task
  if $email_task_result.ok {
    out::message("Email sent successfully.")
  } else {
    fail("Failed to send email notification: ${email_task_result.error.message}")
  }

  # Step 2: Wait for approval email
  out::message("Waiting for approval email...")
  $approval_task_result = run_task('mypatch::await_approval', $targets)

  # Check the result of the approval task
  if $approval_task_result.ok and $approval_task_result['result']['approved'] {
    out::message("Approval received: ${approval_task_result['result']['message']}")
  } else {
    fail("Approval not received: ${approval_task_result['result']['message']}")
  }
}
