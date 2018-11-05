# Set a configuration item in a specific CA instance
#
# The ``$subsystem`` and ``$file`` parameters have been pre-set with the most
# common configuration target.
#
# @option name
#   A useful, unique, name for this resource
#
# @param ca_id
#   The ID (name) of the CA that you will be modifying
#
# @param port
#   The port upon which the service should be listening
#
#   * Used to validate that the service is active
#
# @param timeout
#   How long to wait, in seconds, for the service to start listening
#
# @param key
#   The 'key' that you want to set in the configuration file
#
#   * You can set either `config_hash` OR `key` and `value`, but not both
#   * Must be set if `value` is set
#
# @param value
#   The 'value' to which to set the ``$key`` in the configuration file
#
#   * You can set either `config_hash` OR `key` and `value`, but not both
#   * Must be set if `key` is set
#
# @param config_hash
#   A Hash of key/value pairs that should be added to the system
#
#   * You can set either `config_hash` OR `key` and `value`, but not both
#
# @param value_join
#   If the `value` is an `Array`, this `String` will be used to join the
#   elements
#
# @param subsystem
#   The Dogtag Subsystem that is to be managed (lower case)
#
#   * Has no effect if `target` is set
#
# @param file
#   The specific configuration file to update
#
#   * Has no effect if `target` is set
#
# @param target
#   The full path to the target file
#
define simp_pki_service::ca::config_item (
  String[1]                                      $ca_id,
  Simplib::Port                                  $port,
  Integer[1]                                     $timeout     = 5,
  Optional[String[1]]                            $key         = undef,
  Optional[Variant[String[1], Boolean, Numeric]] $value       = undef,
  Simp_pki_service::Ca::ConfigItemHash           $config_hash = {},
  String[1]                                      $value_join  = ',',
  String[1]                                      $subsystem   = 'ca',
  String[1]                                      $file        = 'CS.cfg',
  Optional[Stdlib::AbsolutePath]                 $target      = undef
){
  if (($key =~ NotUndef) and ($value =~ Undef)) or (($key =~ Undef) and ($value =~ NotUndef)) {
    fail('You must provide both `key` and `value`')
  }
  if ($key =~ NotUndef) and !empty($config_hash) {
    fail('You may only define `key/value` or `config_hash`')
  }

  if $key {
    $_config_hash = { $key => $value }
  }
  else {
    $_config_hash = $config_hash
  }

  if $target {
    $_target = $target
  }
  else {
    $_target = "/var/lib/pki/${ca_id}/${subsystem}/conf/${file}"
  }

  unless empty($_config_hash) {
    $_augeas_commands = $_config_hash.map |$k,$v| {
      if $v =~ Array {
        $_v = join($v, $value_join)
      }
      else {
        $_v = $v
      }

      "set ${k} ${_v}"
    }

    augeas { $name:
      lens    => 'Simplevars.lns',
      incl    => $_target,
      changes => $_augeas_commands,
      notify  => Exec["restart CA instance ${ca_id} for ${name}"]
    }
  }

  ensure_resource('exec', "restart CA instance ${ca_id} for ${name}", {
    command     => "pki-server instance-stop ${ca_id} && pki-server instance-start ${ca_id}",
    refreshonly => true,
    path        => ['/sbin', '/usr/sbin', '/bin', '/usr/bin'],
    notify      => Simp_pki_service::Ca::Wait_for_service["CA ${ca_id} on port ${port} for ${name}"]
  })

  ensure_resource('simp_pki_service::ca::wait_for_service', "CA ${ca_id} on port ${port} for ${name}", {
    port    => $port,
    timeout => $timeout
  })
}
