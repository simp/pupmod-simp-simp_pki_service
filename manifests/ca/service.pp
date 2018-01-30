define simp_pki_service::ca::service (
  $port,
  $timeout = 5
){
  service { "pki-tomcatd@${name}":
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    notify     => Exec["${name} wait for tomcat service"]
  }

  $_port_check = "ss -tln | awk '{ print \$4 }' | rev | cut -f1 -d':' | rev | grep -qe '^${port}\$'"

  exec { "${name} wait for tomcat service":
    command     => $_port_check,
    tries       => $timeout,
    try_sleep   => 2,
    refreshonly => true,
    path        => ['/bin', '/sbin']
  }
}
