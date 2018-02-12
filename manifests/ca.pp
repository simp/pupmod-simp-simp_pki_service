# Set up a Dogtag CA
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
#     * Note: This is probably your root DN
#
# @param dirsrv_bind_password
#   The password for ``dirsrv_bind_dn``
#
# @param pki_security_domain
#   The Security Domain for your CA
#
#     * It is **highly recommended** that you keep groups of related CAs in the
#       same security domain for this module
#
# @param admin_user
#   The CA administrative user
#
# @param admin_password
#   The password for the CA administrative user
#
# @param pki_security_domain_hostname
#   The hostname for the root CA for ``$pki_security_domain``
#
# @param pki_security_domain_https_port
#   The secure port for the root CA for ``$pki_security_domain``
#
# @param root_ca
#   Set if this CA is a root
#
# @param pki_security_domain_user
#   The administrative username for the root CA for ``$pki_security_domain``
#
# @param pki_security_domain_password
#   The administrative password for the root CA for ``$pki_security_domain``
#
# @param create_subordinate_security_domain
#   Add a separate subordinate security domain for this CA
#
#     * Note: Has no effect if ``$root_ca`` is ``true``
#
# @param enable_kra
#   Enable the KRA subsystem for this CA
#
# @param enable_scep
#   Enable the SCEP responder in the KRA
#
#     * Has no functional effect if ``$enable_kra`` is ``false``
#
# @param parent_ca
#   The root CA for this CA
#
#     * Should not be set if this system is a root CA
#
# @param debug_level
#   Set the debug level of the CA and KRA
#
#     * 10 => off
#     * 0  => highest level of debugging
#
# @param package_ensure
#   What to do regarding package installation
#
# @author https://github.com/simp/pupmod-simp-simp_pki_service/graphs/contributors
#
define simp_pki_service::ca (
  Simplib::Port                    $http_port,
  Simplib::Port                    $https_port,
  Simplib::Port                    $tomcat_ajp_port,
  Simplib::Port                    $tomcat_server_port,
  String[2]                        $dirsrv_bind_dn,
  String[1]                        $dirsrv_bind_password,
  Simp_pki_service::SecurityDomain $pki_security_domain,
  String[2]                        $admin_user                         = 'caadmin',
  String[1]                        $admin_password                     = simplib::passgen("${pki_security_domain}_${name}", { 'length' => 64, 'complexity' => 0 }),
  Simplib::Hostname                $pki_security_domain_hostname       = $facts['fqdn'],
  Simplib::Port                    $pki_security_domain_https_port     = 8443,
  Boolean                          $root_ca                            = false,
  String[2]                        $pki_security_domain_user           = $admin_user,
  String[1]                        $pki_security_domain_password       = $admin_password,
  Boolean                          $create_subordinate_security_domain = false,
  Boolean                          $enable_kra                         = false,
  Boolean                          $enable_scep                        = false,
  Optional[String[1]]              $parent_ca                          = undef,
  Integer[0,10]                    $debug_level                        = 10,
  Simplib::PackageEnsure           $package_ensure                     = 'installed'
){
  include simp_pki_service::config

  ensure_packages('pki-ca', { ensure => $package_ensure })

  if $parent_ca {
    Simp_pki_service::Ca[$parent_ca] -> Simp_pki_service::Ca[$name]
  }

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
    require => File[$_ca_config_file],
    notify  => Simp_pki_service::Ca::Service[$name]
  }

  simp_pki_service::ca::service { $name: port => $https_port }

  if $enable_kra {
    if $create_subordinate_security_domain {
      $_kra_pki_security_domain_hostname   = $facts['fqdn']
      $_kra_pki_security_domain_https_port = $https_port
      $_kra_pki_security_domain_user       = $admin_user
      $_kra_pki_security_domain_password   = $admin_password
    }
    else {
      $_kra_pki_security_domain_hostname   = $pki_security_domain_hostname
      $_kra_pki_security_domain_https_port = $pki_security_domain_https_port
      $_kra_pki_security_domain_user       = $pki_security_domain_user
      $_kra_pki_security_domain_password   = $pki_security_domain_password
    }

    simp_pki_service::kra { $name:
      http_port                      => $http_port,
      https_port                     => $https_port,
      tomcat_ajp_port                => $tomcat_ajp_port,
      tomcat_server_port             => $tomcat_server_port,
      dirsrv_bind_dn                 => $dirsrv_bind_dn,
      dirsrv_bind_password           => $dirsrv_bind_password,
      pki_security_domain            => $pki_security_domain,
      pki_security_domain_user       => $_kra_pki_security_domain_user,
      pki_security_domain_password   => $_kra_pki_security_domain_password,
      pki_security_domain_hostname   => $_kra_pki_security_domain_hostname,
      pki_security_domain_https_port => $_kra_pki_security_domain_https_port,
      admin_password                 => $admin_password,
      ca_hostname                    => $facts['fqdn'],
      ca_port                        => $https_port,
      admin_user                     => $admin_user,
      package_ensure                 => $package_ensure,
      require                        => Simp_pki_service::Ca::Service[$name]
    }
  }

  if $enable_scep {
    simp_pki_service::dogtag::config_item { "Enable SCEP on ${name}":
      ca_id   => $name,
      key     => 'ca.scep.enable',
      value   => true,
      require => Exec["Configure SIMP ${name} CA"]
    }

    simp_pki_service::dogtag::config_item { "Disable FlatFileAuth defer on ${name}":
      ca_id   => $name,
      key     => 'auths.instance.flatFileAuth.deferOnFailure',
      value   => false,
      require => Exec["Configure SIMP ${name} CA"]
    }
  }
  else {
    simp_pki_service::dogtag::config_item { "Disable SCEP on ${name}":
      ca_id   => $name,
      key     => 'ca.scep.enable',
      value   => false,
      require => Exec["Configure SIMP ${name} CA"]
    }

    simp_pki_service::dogtag::config_item { "Enable FlatFileAuth defer on ${name}":
      ca_id   => $name,
      key     => 'auths.instance.flatFileAuth.deferOnFailure',
      value   => true,
      require => Exec["Configure SIMP ${name} CA"]
    }
  }

  if $debug_level {
    simp_pki_service::dogtag::config_item { "Enable debug on ${name}":
      ca_id   => $name,
      key     => 'debug.enabled',
      value   => true,
      require => Exec["Configure SIMP ${name} CA"]
    }
    simp_pki_service::dogtag::config_item { "Set debug level on ${name}":
      ca_id   => $name,
      key     => 'debug.level',
      value   => $debug_level,
      require => Exec["Configure SIMP ${name} CA"]
    }
  }
  else {
    simp_pki_service::dogtag::config_item { "Disable debug on ${name}":
      ca_id   => $name,
      key     => 'debug.enabled',
      value   => false,
      require => Exec["Configure SIMP ${name} CA"]
    }
  }
}
