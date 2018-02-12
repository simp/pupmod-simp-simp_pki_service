# Set up a local 389DS for use by Dogtag
#
# @param base_dn
#   The 'base' DN component of the directory server
#
# @param root_dn
#   The default administrator DN for the directory server
#
# @param admin_password
#   The password for the ``$admin_user`` and the ``$root_dn``
#
# @param listen_address
#   The IP address upon which to listen
#
# @param port
#   The port upon which to accept connections
#
# @param enable_admin_service
#   Enable the administrative interface for the GUI
#
# @param admin_user
#   The administrative user for administrative GUI connections
#
# @param admin_service_listen_address
#   The IP address upon which the administrative interface should listen
#
# @param admin_service_port
#   The port upon which the administrative interface should listen
#
# @param service_user
#   The user that ``389ds`` should run as
#
# @param service_group
#   The group that ``389ds`` should run as
#
# @param package_ensure
#   What to do regarding package installation
#
# @author https://github.com/simp/pupmod-simp-simp_pki_service/graphs/contributors
#
define simp_pki_service::directory_server (
  String[2]              $base_dn,
  String[2]              $root_dn,
  Simplib::IP            $listen_address               = '127.0.0.1',
  Simplib::Port          $port                         = 389,
  Boolean                $enable_admin_service         = false,
  String[2]              $admin_user                   = 'admin',
  String[2]              $admin_password               = simplib::passgen("389-ds-${name}", { 'length' => 64, 'complexity' => 0 }),
  Simplib::IP            $admin_service_listen_address = '0.0.0.0',
  Simplib::Port          $admin_service_port           = 9830,
  String[1]              $service_user                 = 'nobody',
  String[1]              $service_group                = 'nobody',
  Simplib::PackageEnsure $package_ensure               = 'installed'
){
  include simp_pki_service::config

  if $enable_admin_service {
    $_389_package = '389-admin'
    $_setup_command = '/sbin/setup-ds-admin.pl'

    ensure_packages(['389-ds-console', '389-admin-console'], { ensure => $package_ensure })
  }
  else {
    $_389_package = '389-ds-base'
    $_setup_command = '/sbin/setup-ds.pl'
  }

  ensure_packages($_389_package, { ensure => $package_ensure })

  $_ds_setup_inf = @("DS_SETUP")
    # This file managed by Puppet
    [General]
    SuiteSpotUserID=${service_user}
    SuiteSpotGroup=${service_group}
    AdminDomain=${facts['domain']}
    FullMachineName=${facts['fqdn']}
    ConfigDirectoryLdapURL=ldap://${facts['fqdn']}:389/o=NetscapeRoot
    ConfigDirectoryAdminID=${admin_user}
    ConfigDirectoryAdminPwd=${admin_password}

    [slapd]
    ServerPort=${port}
    ServerIdentifier=${name}
    Suffix=${base_dn}
    RootDN=${root_dn}
    RootDNPwd=${admin_password}
    SlapdConfigForMC=yes
    AddOrgEntries=yes
    AddSampleEntries=no

    [admin]
    Port=${admin_service_port}
    ServerAdminID=${admin_user}
    ServerAdminPwd=${admin_password}
    ServerIpAddress=${admin_service_listen_address}
    | DS_SETUP

  $_ds_config_file = "${simp_pki_service::config::generated_config_dir}/ds_${name}_setup.inf"

  file { $_ds_config_file:
    owner                   => 'root',
    group                   => 'root',
    mode                    => '0600',
    selinux_ignore_defaults => true,
    content                 => Sensitive($_ds_setup_inf),
    require                 => Package[$_389_package]
  }

  $_ds_instance_config = "/etc/dirsrv/slapd-${name}/dse.ldif"

  exec { "Setup ${name} DS":
    command => "${_setup_command} --silent -f ${_ds_config_file}",
    creates => $_ds_instance_config,
    require => File[$_ds_config_file],
    notify  => Service["dirsrv@${name}"]
  }

  $_ds_pw_file = "${simp_pki_service::config::generated_config_dir}/ds_pw.txt"

  file { $_ds_pw_file:
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0400',
    content => Sensitive($admin_password),
    require => Exec["Setup ${name} DS"]
  }

  ensure_resource('service', "dirsrv@${name}",
    {
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
  )

  simp_pki_service::directory_server::conf_item { "Set nsslapd-listenhost on ${name}":
    key             => 'nsslapd-listenhost',
    value           => $listen_address,
    admin_dn        => $root_dn,
    pw_file         => $_ds_pw_file,
    ds_host         => $listen_address,
    ds_port         => $port,
    ds_service_name => "dirsrv@${name}"
  }

  simp_pki_service::directory_server::conf_item { "Set nsslapd-securelistenhost on ${name}":
    key             => 'nsslapd-securelistenhost',
    value           => $listen_address,
    admin_dn        => $root_dn,
    pw_file         => $_ds_pw_file,
    ds_host         => $listen_address,
    ds_port         => $port,
    ds_service_name => "dirsrv@${name}"
  }
}
