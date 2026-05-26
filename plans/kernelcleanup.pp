plan mypatch::kernelcleanup(
  TargetSpec $targets,
) {
  # Run the kernel cleanup task and return its results.
  # The task already performs the same pre-checks, cleanup, pause, and post-checks.
  $results = run_task('mypatch::kernelcleanup', $targets)
  return $results
}

