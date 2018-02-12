# Modifies the running directory server configuration and restarts the service
# when necessary.
#
# **IMPORTANT** Do not set sensitive values with this until it switches over to
# being a native type!
#
# @option name [String]
#   A unique description of the desired configuration setting
#
# @param key
#   The configuration key to be set
#
#     * You can get a list of all configuration keys by running:
#       ``ldapsearch -H ldap://localhost:389 -y $HOME/.dogtag/generated_configs/ds_pw.txt \
#       -D "cn=SIMP Directory Manager" -s base -b "cn=config"``
#
# @param value
#   The value that should be set for ``$key``
#
# @param admin_dn
#   A DN with administrative rights to the directory
#
# @param pw_file
#   A file containing the password for use with ``$admin_dn``
#
# @param ds_service_name
#   The Puppet resource name for the directory ``Service`` resource
#
# @param restart_service
#   Whether or not to restart the directory server after applying this item
#
#     * There is a known list of items in the module data that will always
#       generate a restart action
#
# @param ds_host
#   The host where the service is running
#
# @param ds_port
#   The port to which to connect
#
# @param base_dn
#   The DN that holds the directory configuration items
#
define simp_pki_service::directory_server::conf_item (
  $key,
  $value,
  $admin_dn,
  $pw_file,
  $ds_service_name,
  $restart_service = false,
  $ds_host = '127.0.0.1',
  $ds_port = '389',
  $base_dn = 'cn=config'
) {

  $_ldap_command_base = "-x -D '${admin_dn}' -y '${pw_file}' -H ldap://${ds_host}:${ds_port}"

  # Force encryption if going off system
  if $ds_host in ['127.0.0.1', 'localhost', '::1'] {
    $_ldap_command_extra = ''
  }
  else {
    $_ldap_command_extra = '-ZZ'
  }

  # This should be a provider
  exec { "Set ${base_dn},${key} on ${ds_host}":
    command => "echo -e \"dn: ${base_dn}\\nchangetype: modify\\nreplace: ${key}\\n${key}: ${value}\" | ldapmodify ${_ldap_command_base}",
    unless  => "test `ldapsearch ${_ldap_command_extra} ${_ldap_command_base} -LLL -s base -b '${base_dn}' ${key} | grep -e '^${key}' | awk '{ print \$2 }'` == '${value}'",
    path    => ['/bin', '/usr/bin']
  }

  if $restart_service or (
    $name in lookup('simp_pki_service::directory_server::config::attributes_requiring_restart')
  ) {
    ensure_resource('service', $ds_service_name, {})

    Exec["Set ${base_dn},${key} on ${ds_host}"] ~> Service[$ds_service_name]
  }
}
