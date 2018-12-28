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
# @param parent_ca
#   The root CA for this CA
#
#     * Should not be set if this system is a root CA
#
# @param ca_config
#   A 'one-to-one' configuration Hash for the CA
#
#   * Each `key`/`value` pair is directly mapped into the CA's `CS.cfg` file
#     without type checking
#   * For example, to enable the SCEP responder, you would set `ca.scep.enable`
#     to `true`
#
# @param kra_config
#   A 'one-to-one' configuration Hash for the KRA
#
#   * Each `key`/`value` pair is directly mapped into the KRA's `CS.cfg` file
#     without type checking
#
#
# @param scep_profile_config
#   A 'one-to-one' configuration Hash that will udpdate the values in the 'caRouterCert.cfg'
#
#   * Each `key`/`value` pair is directly mapped into the CA's caRouterCert.cfg
#     profile file since this is hard coded for SCEP use.
#   * No validity checking is performed.
#
# @param debug_level
#   Set the debug level of the CA and KRA
#
#     * 10 => off
#     * 0  => highest level of debugging
#
# @param service_timeout
#   The number of seconds to wait for the service to listen on `http_port`
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
  Optional[String[1]]              $parent_ca                          = undef,
  Hash                             $ca_config                          = {},
  Hash                             $kra_config                         = {},
  Hash                             $scep_profile_config                = {
    'desc'                                                                 => 'This certificate profile is for enrolling server certificates via SCEP.',
    'name'                                                                 => 'One Time Pin Server Certificate Enrollment',
    'policyset.serverCertSet.6.constraint.params.keyUsageDataEncipherment' => true,
    'policyset.serverCertSet.6.default.params.keyUsageDataEncipherment'    => true,
    'policyset.serverCertSet.7.default.params.exKeyUsageOIDs'              => ['1.3.6.1.5.5.7.3.1','1.3.6.1.5.5.7.3.2','1.3.6.1.5.5.7.3.4']
  },
  Integer[0,10]                    $debug_level                        = 10,
  Integer[1]                       $service_timeout                    = 5,
  Simplib::PackageEnsure           $package_ensure                     = simplib::lookup('simp_options::package_ensure', { 'default_value'  => 'installed' })
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

  simp_pki_service::ca::service { $name:
    port    => $https_port,
    timeout => $service_timeout
  }

  if $debug_level {
    $_debug_ca_config = {
      'debug.enabled' => true,
      'debug.level'   => $debug_level
    }
  }
  else {
    $_debug_ca_config = {
      'debug.enabled' => false
    }
  }

  if $ca_config['ca.scep.enable'] == true {
    # Updating auths.instance.flatFileAuth.deferOnFailure is required by
    # default but the user may want to override it
    $_scep_ca_config = {
      'auths.instance.flatFileAuth.deferOnFailure' => false
    }

    # Update the 'caRouterCert.cfg' to allow for the provisioning of server
    # certificates by default.
    simp_pki_service::ca::config_item { "Change Router profile to Server profile for CA ${name}":
      target      => "/var/lib/pki/${name}/ca/profiles/caRouterCert.cfg",
      ca_id       => $name,
      port        => $http_port,
      timeout     => $service_timeout,
      config_hash => $scep_profile_config,
      require     => Exec["Configure SIMP ${name} CA"]
    }
  }
  else {
    $_scep_ca_config = {}
  }

  simp_pki_service::ca::config_item { "Update config for CA ${name}":
    ca_id       => $name,
    port        => $http_port,
    timeout     => $service_timeout,
    config_hash => merge($_scep_ca_config, merge($_debug_ca_config, $ca_config)),
    require     => Exec["Configure SIMP ${name} CA"]
  }

  if $enable_kra or ( $ca_config['ca.scep.enable'] == true ) {
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
      service_timeout                => $service_timeout,
      kra_config                     => $kra_config,
      package_ensure                 => $package_ensure,
      require                        => Simp_pki_service::Ca::Service[$name]
    }
  }
}
