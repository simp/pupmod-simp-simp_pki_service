define simp_pki_service::ca (
  $http_port,
  $https_port,
  $tomcat_ajp_port,
  $tomcat_server_port,
  $dirsrv_bind_dn,
  $admin_password,
  $pki_security_domain,
  $admin_user = 'caadmin',
  $pki_security_domain_hostname = $facts['fqdn'],
  $pki_security_domain_user = $admin_user,
  $pki_security_domain_password = $admin_password,
  $pki_security_domain_https_port = 8443,
  $root_ca = false,
  $package_ensure = 'installed'
){
  include simp_pki_service::config

  ensure_packages('pki-ca', { ensure => $package_ensure })

  $_ca_config_file = "${simp_pki_service::config::generated_config_dir}/dogtag_${name}_ca.cfg"

  file { $_ca_config_file:
    owner                   => 'root',
    group                   => 'root',
    mode                    => '0600',
    content                 => Sensitive(template("${module_name}/ca/ca.cfg.erb")),
    selinux_ignore_defaults => true,
    require                 => Package['pki-ca'],
    before                  => Exec["Configure SIMP ${name} CA"]
  }

  exec { "Configure SIMP ${name} CA":
    command => "/sbin/pkispawn -f ${_ca_config_file} -s CA || ( /sbin/pkidestroy -i ${name} -s CA >& /dev/null && exit 1 )",
    creates => "/etc/sysconfig/pki/tomcat/${name}/ca/manifest",
    require => File[$_ca_config_file]
  }
}
