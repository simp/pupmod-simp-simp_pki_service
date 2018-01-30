define simp_pki_service::kra (
  Simplib::Port $https_port,
  Simplib::Port $http_port,
  $dirsrv_bind_dn,
  $admin_password,
  $pki_security_domain,
  $ca_hostname,
  $ca_port,
  $tomcat_ajp_port,
  $tomcat_server_port,
  $package_ensure = 'installed'
){
  include simp_pki_service::config

  ensure_packages('pki-kra', { ensure => $package_ensure })

  $_kra_config = @("KRA_CONFIG")
    # This file managed by Puppet
    [DEFAULT]
    pki_instance_name=${name}

    pki_security_domain_name=${pki_security_domain}
    pki_security_domain_hostname=${ca_hostname}
    pki_security_domain_https_port=${ca_port}
    pki_security_domain_user=caadmin
    pki_security_domain_password=${admin_password}

    [KRA]
    pki_ds_hostname=127.0.0.1
    pki_ds_bind_dn=${dirsrv_bind_dn}

    pki_client_database_password=${admin_password}
    pki_client_pkcs12_password=${admin_password}

    pki_ds_database=${name}-kra
    pki_ds_password=${admin_password}

    pki_admin_password=${admin_password}

    pki_http_port=${http_port}
    pki_https_port=${https_port}

    pki_admin_cert_file=/root/.dogtag/${name}/ca_admin.cert
    pki_admin_email=kraadmin@${facts['fqdn']}
    pki_admin_name=kraadmin
    pki_admin_nickname=kraadmin
    pki_admin_uid=kraadmin

    pki_issuing_ca_hostname=${ca_hostname}
    pki_issuing_ca_https_port=${ca_port}

    [Tomcat]
    pki_ajp_port=${tomcat_ajp_port}
    pki_tomcat_server_port=${tomcat_server_port}
    | KRA_CONFIG

  $_kra_config_file = "${simp_pki_service::config::generated_config_dir}/dogtag_${name}_kra.cfg"

  file { $_kra_config_file:
    owner                   => 'root',
    group                   => 'root',
    mode                    => '0600',
    selinux_ignore_defaults => true,
    content                 => Sensitive($_kra_config),
    before                  => Exec["Configure SIMP ${name} KRA"]
  }

  exec { "Configure SIMP ${name} KRA":
    command => "/sbin/pkispawn -f ${_kra_config_file} -s KRA || ( /sbin/pkidestroy -i ${name} -s KRA >& /dev/null && exit 1 )",
    creates => "/etc/sysconfig/pki/tomcat/${name}/kra/manifest",
    require => Package['pki-kra']
  }
}
