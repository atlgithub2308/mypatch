plan mypatch::auto_patch (
  String $patch_group,
  Boolean $security_only = false,
  Enum['always', 'never', 'patched', 'smart'] $reboot = 'patched',
){
  # Query PuppetDB to find nodes that have the patch group,
  # are not blocked and have patches to apply
  $all_nodes = puppetdb_query("inventory[certname] { facts.pe_patch.patch_group = '${patch_group}'}")
  $filtered_nodes = puppetdb_query("inventory[certname] { facts.pe_patch.patch_group = '${patch_group}' and facts.pe_patch.blocked = false and facts.pe_patch.package_update_count > 0}")

  # Transform the query output into Targetspec
  $full_list = $all_nodes.map | $r | { $r['certname'] }
  $certnames = $filtered_nodes.map | $r | { $r['certname'] }
  #$pcp = $certnames.map | $t | { "pcp://$t" }
  $targets = get_targets($certnames)

  # Start the work
  if $targets.empty {
    # Set the return variables to empty as there is nothing to patch
    $puppet_not_healthy = []
    $node_not_healthy = []
    $not_patched = []
    $check_failed = []
    $check_passed = []
    $pre_update_failed = []
    $post_update_failed = []
  } else {
    # Check the health of the puppet agent on all nodes
    $agent_health = run_task('puppet_health_check::agent_health', $targets, '_catch_errors' => true)

    # Pull out list of those that are ok/in error
    $puppet_healthy = $agent_health.ok_set.names
    $puppet_not_healthy = $agent_health.error_set.names

    # Proceed there are health agents
    if $puppet_healthy.empty {
      $node_not_healthy = []
      $not_patched = []
      $check_failed = []
      $check_passed = []
      $pre_update_failed = []
      $post_update_failed = []
    } else {
      # Do pre-patching health checks
      $health_check = run_task('enterprise_tasks::run_puppet', $puppet_healthy, '_catch_errors' => true)

      # Pull out list of those that are ok/in error
      $node_healthy = $health_check.ok_set.names
      $node_not_healthy = $health_check.error_set.names

      # Proceed there are health nodes
      if $node_healthy.empty {
        $not_patched = []
        $check_failed = []
        $check_passed = []
        $pre_update_failed = []
        $post_update_failed = []
      } else {
        $to_pre_update = run_task('patching::pre_update', $node_healthy, '_catch_errors' =>  true)

        $pre_update_done = $to_pre_update.ok_set.names
        $pre_update_failed = $to_pre_update.error_set.names

        # Actually carry out the patching on all healthy nodes
        $to_patch = run_task('pe_patch::patch_server',
                              $pre_update_done,
                              reboot          => $reboot,
                              security_only   => $security_only,
                              '_catch_errors' => true
                    )
        # Pull out list of those that are ok/in error
        $patched = $to_patch.ok_set.names
        $not_patched = $to_patch.error_set.names

        # Wait until the nodes are back up
        $to_post_check = wait_until_available($node_healthy, wait_time => 300)

        # Pull out list of those that are ok/in error
        $rebooted = $to_post_check.ok_set.names
        $not_rebooted = $to_post_check.error_set.names

        # Do post-patching health checks
        $to_post_update = run_task('patching::post_update',
                              $rebooted,
                              '_catch_errors' => true
                          )

        $post_update_done = $to_post_update.ok_set.names
        $post_update_failed = $to_post_update.error_set.names
        $post_check = run_task('enterprise_tasks::run_puppet', $post_update_done, '_catch_errors' => true)
        $check_passed = $post_check.ok_set.names
        $check_failed = $post_check.error_set.names
      }
    }
  }

  # Output the results
  return({
    'patch_group'                => $patch_group,
    'all_nodes_in_group'         => $full_list,
    'patchable_nodes'            => $targets,
    'puppet_health_check_failed' => $puppet_not_healthy,
    'node_health_check_failed'   => $node_not_healthy,
    'patching_failed'            => $not_patched,
    'post_check_failed'          => $check_failed,
    'nodes_patched'              => $check_passed,
    'pre_update_failed'          => $pre_update_failed,
    'post_update_failed'         => $post_update_failed,
    'counts'                     => {
      'all_nodes_in_group_count'   => $full_list.count,
      'patchable_nodes_count'      => $targets.count,
      'puppet_health_check_failed' => $puppet_not_healthy.count,
      'node_health_check_failed'   => $node_not_healthy.count,
      'patching_failed'            => $not_patched.count,
      'post_check_failed'          => $check_failed.count,
      'nodes_patched'              => $check_passed.count,
      'pre_update_failed'          => $pre_update_failed.count,
      'post_update_failed'         => $post_update_failed.count,
    }
  })
}
