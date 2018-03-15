# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**
#
# Wait for the given `timeout` for the service on `port` to start.
#
# This is present because the Dogtag services will return that they are fully
# functional prior to actually listening on a port.
#
# @param port
#   The port upon which to listen
#
# @param timeout
#   How long to wait, in seconds, for the daemon to start listening
#
define simp_pki_service::ca::wait_for_service (
  Simplib::Port $port,
  Integer[1]    $timeout = 5
){
  assert_private()

  $_port_check = "ss -tln | awk '{ print \$4 }' | rev | cut -f1 -d':' | rev | grep -qe '^${port}\$'"

  exec { $name:
    command     => $_port_check,
    tries       => $timeout,
    try_sleep   => 2,
    refreshonly => true,
    path        => ['/bin', '/sbin']
  }
}
