define simp_pki_service::directory_server (
  $dirsrv_base_dn,
  $dirsrv_root_dn,
  $admin_password,
  $enable_admin_service = false,
  $admin_service_port = 9830,
  $admin_user = 'admin',
  $admin_ip_address = '0.0.0.0',
  $package_ensure = 'installed',
  $listen_address = '127.0.0.1'
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
    SuiteSpotUserID=nobody
    SuiteSpotGroup=nobody
    AdminDomain=${facts['domain']}
    FullMachineName=${facts['fqdn']}
    ConfigDirectoryLdapURL=ldap://${facts['fqdn']}:389/o=NetscapeRoot
    ConfigDirectoryAdminID=${admin_user}
    ConfigDirectoryAdminPwd=${admin_password}

    [slapd]
    ServerPort=389
    ServerIdentifier=${name}
    Suffix=${dirsrv_base_dn}
    RootDN=${dirsrv_root_dn}
    RootDNPwd=${admin_password}
    SlapdConfigForMC=yes
    AddOrgEntries=yes
    AddSampleEntries=no

    [admin]
    Port=${admin_service_port}
    ServerAdminID=${admin_user}
    ServerAdminPwd=${admin_password}
    ServerIpAddress=${admin_ip_address}
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
    command => "${_setup_command} --silent -f $_ds_config_file",
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

  simp_pki_service::directory_server::conf_item { 'nsslapd-listenhost': value => $listen_address }
  simp_pki_service::directory_server::conf_item { 'nsslapd-securelistenhost': value => $listen_address }
}
