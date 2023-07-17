# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**
#
# Set up a Dogtag KRA
#
# This should only be called from the ``simp_pki_service::ca`` define. Doing
# otherwise may work but is an untested configuration.
#
# @param http_port
#   The insecure port
#
# @param https_port
#   The secure port
#
# @param tomcat_ajp_port
#   The Apache JServ Protocol port
#
# @param tomcat_server_port
#   Port used to shutdown Tomcat
#
# @param dirsrv_bind_dn
#   The bind_dn for 389DS
#
# @param dirsrv_bind_password
#   The password for ``dirsrv_bind_dn``
#
# @param pki_security_domain
#   The Security Domain for your KRA
#
#     * It is **highly recommended** that you keep groups of related CAs in the
#       same security domain for this module.
#
# @param pki_security_domain_user
#   The administrative username for the root CA for ``$pki_security_domain``
#
# @param pki_security_domain_password
#   The administrative password for the root CA for ``$pki_security_domain``
#
# @param pki_security_domain_hostname
#   The hostname for the root CA for ``$pki_security_domain``
#
# @param pki_security_domain_https_port
#   The secure port for the root CA for ``$pki_security_domain``
#
# @param admin_password
#   The password for the CA administrative user specified in ``$admin_user``
#
# @param ca_hostname
#   The hostname of the CA that this KRA is bound to
#
# @param ca_port
#   The port of the CA that this KRA is bound to
#
# @param admin_user
#   The administrative user of the CA that this KRA is bound to
#
# @param kra_config
#   A `key`/`value` pair set that will be fed directly into the KRA `CS.cfg`
#
# @param service_timeout
#   The number of seconds to wait for the service to listen on `http_port`
#
# @param package_ensure
#   What to do regarding package installation
#
# @author https://github.com/simp/pupmod-simp-simp_pki_service/graphs/contributors
#
define simp_pki_service::kra (
  Simplib::Port                    $http_port,
  Simplib::Port                    $https_port,
  Simplib::Port                    $tomcat_ajp_port,
  Simplib::Port                    $tomcat_server_port,
  String[2]                        $dirsrv_bind_dn,
  String[1]                        $dirsrv_bind_password,
  Simp_pki_service::SecurityDomain $pki_security_domain,
  String[2]                        $pki_security_domain_user,
  String[2]                        $pki_security_domain_password,
  Simplib::Hostname                $pki_security_domain_hostname,
  Simplib::Port                    $pki_security_domain_https_port,
  String[1]                        $admin_password,
  Simplib::Hostname                $ca_hostname,
  Simplib::Port                    $ca_port,
  String[1]                        $admin_user                      = 'caadmin',
  Hash                             $kra_config                      = {},
  Integer[1]                       $service_timeout                 = 5,
  Simplib::PackageEnsure           $package_ensure                  = simplib::lookup('simp_options::package_ensure', { 'default_value'  => 'installed' })
){
  assert_private()

  include simp_pki_service::config

  ensure_packages('pki-kra', { ensure => $package_ensure })

  $_fqdn = $facts['networking']['fqdn']
  $_kra_config = @("KRA_CONFIG")
    # This file managed by Puppet
    [DEFAULT]
    pki_instance_name=${name}

    pki_security_domain_name=${pki_security_domain}
    pki_security_domain_hostname=${pki_security_domain_hostname}
    pki_security_domain_https_port=${pki_security_domain_https_port}
    pki_security_domain_user=${pki_security_domain_user}
    pki_security_domain_password=${pki_security_domain_password}

    [KRA]
    pki_ds_hostname=127.0.0.1
    pki_ds_bind_dn=${dirsrv_bind_dn}

    pki_ds_database=${name}-kra
    pki_ds_password=${dirsrv_bind_password}

    pki_client_database_password=${admin_password}
    pki_client_pkcs12_password=${admin_password}

    pki_admin_password=${admin_password}

    pki_http_port=${http_port}
    pki_https_port=${https_port}

    pki_admin_cert_file=/root/.dogtag/${name}/ca_admin.cert
    pki_admin_email=kraadmin@${_fqdn}
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

  simp_pki_service::ca::config_item { "Update config for KRA ${name}":
    ca_id       => $name,
    port        => $http_port,
    timeout     => $service_timeout,
    config_hash => $kra_config,
    subsystem   => 'kra',
    require     => Exec["Configure SIMP ${name} KRA"]
  }
}
