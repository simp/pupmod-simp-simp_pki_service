class simp_pki_service (
  # Set in module data
  Simp_pki_service::SecurityDomain $pki_security_domain,
  String[4]                        $dirsrv_root_dn,
  String[16]                       $admin_password              = simplib::passgen('simp_pki_service', { 'length' => 64, 'complexity' => 0 }),
  String[4]                        $dirsrv_base_dn              = sprintf('ou=%s,%s',$pki_security_domain, simplib::ldap::domain_to_dn($facts['domain'], false)),
  Simplib::IP                      $dirsrv_listen_address       = '127.0.0.1',
  Boolean                          $dirsrv_enable_admin_service = false,
  Simp_Pki_service::Ca_config      $custom_cas                  = {},
  Simp_pki_service::Ca_config      $cas                         = {
    'simp-pki-root' => {
      'root_ca'            => true,
      'enable_kra'         => false,
      'http_port'          => 4508,
      'https_port'         => 4509,
      'tomcat_ajp_port'    => 4506,
      'tomcat_server_port' => 4507
    },
    'simp-puppet-pki' => {
      'enable_scep'        => true,
      'http_port'          => 5508,
      'https_port'         => 5509,
      'tomcat_ajp_port'    => 5506,
      'tomcat_server_port' => 5507,
      'parent_ca'          => 'simp-pki-root'
    },
    'simp-site-pki' => {
      'enable_scep'        => true,
      'http_port'          => 8080,
      'https_port'         => 8443,
      'tomcat_ajp_port'    => 8440,
      'tomcat_server_port' => 8441,
      'parent_ca'          => 'simp-pki-root'
    }
  }
){
  include haveged
  include simp_pki_service::config

  simp_pki_service::directory_server { 'simp-pki-ds':
    dirsrv_base_dn       => $dirsrv_base_dn,
    dirsrv_root_dn       => $dirsrv_root_dn,
    admin_password       => $admin_password,
    enable_admin_service => $dirsrv_enable_admin_service,
    listen_address       => $dirsrv_listen_address
  }

  $_cas = deep_merge($cas, $custom_cas)

  keys($_cas).each |String $ca_id| {
    if $_cas[$ca_id]['root_ca'] {
      simp_pki_service::ca { $ca_id:
        admin_password                 => $admin_password,
        http_port                      => $_cas[$ca_id]['http_port'],
        https_port                     => $_cas[$ca_id]['https_port'],
        dirsrv_bind_dn                 => $dirsrv_root_dn,
        tomcat_ajp_port                => $_cas[$ca_id]['tomcat_ajp_port'],
        tomcat_server_port             => $_cas[$ca_id]['tomcat_server_port'],
        root_ca                        => $_cas[$ca_id]['root_ca'],
        pki_security_domain            => $pki_security_domain,
        pki_security_domain_https_port => $_cas[$ca_id]['https_port'],
        require                        => Simp_pki_service::Directory_server['simp-pki-ds'],
        notify                         => Simp_pki_service::Ca::Service[$ca_id]
      }
    }
    else {
      simp_pki_service::ca { $ca_id:
        admin_password                 => $admin_password,
        http_port                      => $_cas[$ca_id]['http_port'],
        https_port                     => $_cas[$ca_id]['https_port'],
        tomcat_ajp_port                => $_cas[$ca_id]['tomcat_ajp_port'],
        tomcat_server_port             => $_cas[$ca_id]['tomcat_server_port'],
        dirsrv_bind_dn                 => $dirsrv_root_dn,
        pki_security_domain            => $pki_security_domain,
        pki_security_domain_https_port => $_cas[$_cas[$ca_id]['parent_ca']]['https_port'],
        notify                         => Simp_pki_service::Ca::Service[$ca_id]
      }
    }

    simp_pki_service::ca::service { $ca_id:
      port => $_cas[$ca_id]['https_port']
    }

    if $_cas[$ca_id]['root_ca'] {
      $_kra_security_domain = $pki_security_domain
    }
    else {
      #$_kra_security_domain = "${pki_security_domain}-${ca_id}"
      $_kra_security_domain = $pki_security_domain
    }

    unless ($_cas[$ca_id]['enable_kra'] == false) {
      simp_pki_service::kra { $ca_id:
        admin_password      => $admin_password,
        http_port           => $_cas[$ca_id]['http_port'],
        https_port          => $_cas[$ca_id]['https_port'],
        dirsrv_bind_dn      => $dirsrv_root_dn,
        pki_security_domain => $_kra_security_domain,
        ca_hostname         => $facts['fqdn'],
        ca_port             => $_cas[$ca_id]['https_port'],
        require             => Simp_pki_service::Ca::Service[$ca_id],
        tomcat_ajp_port     => $_cas[$ca_id]['tomcat_ajp_port'],
        tomcat_server_port  => $_cas[$ca_id]['tomcat_server_port']
      }
    }

    if $_cas[$ca_id]['parent_ca'] {
      Simp_pki_service::Ca[$_cas[$ca_id]['parent_ca']] -> Simp_pki_service::Ca[$ca_id]
      unless ($_cas[$ca_id]['enable_kra'] == false) {
        Simp_pki_service::Ca[$_cas[$ca_id]['parent_ca']] -> Simp_pki_service::Kra[$ca_id]
      }
    }

    if $_cas[$ca_id]['debug_level'] {
      simp_pki_service::dogtag::config_item { "Enable debug on ${ca_id}":
        ca_id => $ca_id,
        key   => 'debug.enabled',
        value => true
      }
      simp_pki_service::dogtag::config_item { "Set debug level on ${ca_id}":
        ca_id => $ca_id,
        key   => 'debug.level',
        value => $_cas[$ca_id]['debug_level']
      }
    }
    else {
      simp_pki_service::dogtag::config_item { "Disable debug on ${ca_id}":
        ca_id => $ca_id,
        key   => 'debug.enabled',
        value => false
      }
    }

    if $_cas[$ca_id]['enable_scep'] {
      simp_pki_service::dogtag::config_item { "Enable SCEP on ${ca_id}":
        ca_id => $ca_id,
        key   => 'ca.scep.enable',
        value => true
      }

      simp_pki_service::dogtag::config_item { "Disable FlatFileAuth defer on ${ca_id}":
        ca_id => $ca_id,
        key   => 'auths.instance.flatFileAuth.deferOnFailure',
        value => false
      }
    }
    else {
      simp_pki_service::dogtag::config_item { "Disable SCEP on ${ca_id}":
        ca_id => $ca_id,
        key   => 'ca.scep.enable',
        value => false
      }

      simp_pki_service::dogtag::config_item { "Enable FlatFileAuth defer on ${ca_id}":
        ca_id => $ca_id,
        key   => 'auths.instance.flatFileAuth.deferOnFailure',
        value => true
      }
    }
  }
}
