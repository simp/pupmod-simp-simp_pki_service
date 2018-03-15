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
    notify     => Simp_pki_service::Ca::Wait_for_service["CA ${name} on port ${port}"]
  }

  ensure_resource('simp_pki_service::ca::wait_for_service', "CA ${name} on port ${port}", {
    port    => $port,
    timeout => $timeout
  })
}
