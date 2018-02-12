# Set a configuration item in a specific Dogtag instance
#
# The ``$subsystem`` and ``$file`` parameters have been pre-set with the most
# common configuraiton target.
#
# @option name
#   A useful, unique, name for this resource
#
# @param ca_id
#   The ID (name) of the CA that you will be modifying
#
# @param key
#   The 'key' that you want to set in the configuration file
#
# @param value
#   The 'value' to which to set the ``$key`` in the configuraiton file
#
# @param subsystem
#   The Dogtag Subsystem that is to be managed (lower case)
#
# @param file
#   The specific configuration file to update
define simp_pki_service::dogtag::config_item (
  $ca_id,
  $key,
  $value,
  $subsystem = 'ca',
  $file      = 'CS.cfg'
){
  augeas { $name:
    lens    => 'Simplevars.lns',
    incl    => "/var/lib/pki/${ca_id}/${subsystem}/conf/${file}",
    changes => [
      "set ${key} ${value}"
    ],
    notify  => Simp_pki_service::Ca::Service[$ca_id]
  }
}
