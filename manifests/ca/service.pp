# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**
#
# Start a CA service on the given port and wait until the service has
# successfully started or the timeout is reached.
#
# @param port
#   The port upon which to listen
#
# @param timeout
#   How long to wait, in seconds, for the daemon to start
define simp_pki_service::ca::service (
  Simplib::Port $port,
  Integer[1]    $timeout = 5
){
  assert_private()

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
