# stop_httpd.pp
node 'sgdemorocky2.atl88.online' {
  exec { 'stop_httpd_service':
    command     => '/usr/bin/sudo systemctl stop httpd',
    unless      => '/usr/bin/systemctl is-active --quiet httpd',
    path        => ['/usr/bin', '/usr/sbin'],
    user        => 'root',
    environment => ['PATH=/usr/bin:/usr/sbin'],
  }

  notify { 'httpd service stopped successfully':
    message => "The httpd service has been successfully stopped on sgdemorocky2.atl88.online.",
    level   => notice,
  }
}
