# Don't set sensitive values with this until it switches over to being a
# provider!
define simp_pki_service::directory_server::conf_item (
  $value,
  $admin_dn = lookup('simp_pki_service::dirsrv_root_dn'),
  $pw_file = sprintf('%s/ds_pw.txt', lookup('simp_pki_service::config::generated_config_dir')),
  $ds_host = '127.0.0.1',
  $ds_port = '389',
  $restart_service = false,
  $ds_service_name = 'dirsrv@simp-pki-ds',
  $base_dn = 'cn=config'
) {

  $_ldap_command_base = "-x -D '${admin_dn}' -y '${pw_file}' -H ldap://${ds_host}:${ds_port}"

  # This should be a provider
  exec { "Set ${base_dn},${name} on ${ds_host}":
    command => "echo -e \"dn: ${base_dn}\\nchangetype: modify\\nreplace: ${name}\\n${name}: ${value}\" | ldapmodify ${_ldap_command_base}",
    unless  => "test `ldapsearch ${_ldap_command_base} -LLL -s base -b '${base_dn}' ${name} | grep -e '^${name}' | awk '{ print \$2 }'` == '${value}'",
    path    => ['/bin', '/usr/bin']
  }

  if $restart_service or (
    $name in lookup('simp_pki_service::directory_server::config::attributes_requiring_restart')
  ) {
    ensure_resource('service', $ds_service_name, {})

    Exec["Set ${base_dn},${name} on ${ds_host}"] ~> Service[$ds_service_name]
  }
}
