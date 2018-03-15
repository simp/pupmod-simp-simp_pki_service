# Creates a single-host Dogtag CA with active sub-CAs
#
# @param pki_security_domain
#   A unique name for the security domain for the CA collection
#
# @param ds_config
#   Backend 389DS data storage configuration for Dogtag
#
#     * This is passed directly into the ``simp_pki_service::directory_server``
#       defined type
#
# @param cas
#   A Hash of CA entries that are passed directly into the
#   ``simp_pki_service::ca`` defined type
#
#   * Hash keys are the parameters in ``simp_pki_service::ca``
#   * Nested Sub CAs are currently not supported
#
# @param custom_cas
#   A user-provided Hash of additional CA entries that are passed directly into
#   the ``simp_pki_service::ca`` defined type
#
#     * NOTE: These will be **deep merged** into the regular ``$cas`` parameter
#
# @param enable_haveged
#   Enable the HAVEGEd entropy collection daemon
#
class simp_pki_service (
  Simp_pki_service::SecurityDomain $pki_security_domain          = 'SIMP',
  Hash                             $ds_config                    = {
    'root_dn'        => "cn=${pki_security_domain} Directory Manager",
    'base_dn'        => sprintf('ou=%s,%s',$pki_security_domain, simplib::ldap::domain_to_dn($facts['domain'], false)),
    'admin_password' => simplib::passgen('389-ds-simp-pki', {'length' => 64, 'complexity' => 0 })
  },
  Hash[String[1], Hash]            $cas                          = {
    'simp-pki-root' => {
      'root_ca'             => true,
      'pki_security_domain' => $pki_security_domain,
      # The following two items need to be here so that the other CA instances
      # can use them for connecting to the security domain
      'admin_user'         => 'caadmin',
      'admin_password'     => simplib::passgen("${pki_security_domain}_simp-pki-root", { 'length' => 64, 'complexity' => 0 }),
      'http_port'          => 4508,
      'https_port'         => 4509,
      'tomcat_ajp_port'    => 4506,
      'tomcat_server_port' => 4507
    },
    'simp-puppet-pki' => {
      'enable_kra'         => true,
      'http_port'          => 5508,
      'https_port'         => 5509,
      'tomcat_ajp_port'    => 5506,
      'tomcat_server_port' => 5507,
      'parent_ca'          => 'simp-pki-root',
      'ca_config'          => {
        'ca.scep.enable' => true
      }
    },
    'simp-site-pki' => {
      'enable_kra'         => true,
      'http_port'          => 8080,
      'https_port'         => 8443,
      'tomcat_ajp_port'    => 8440,
      'tomcat_server_port' => 8441,
      'parent_ca'          => 'simp-pki-root',
      'ca_config'          => {
        'ca.scep.enable' => true
      }
    }
  },
  Hash[String[1], Hash]            $custom_cas                   = {},
  Boolean                          $enable_haveged               = simplib::lookup('simp_options::haveged', { 'default_value'  => true })
){
  if $enable_haveged { include haveged }
  include simp_pki_service::config

  simp_pki_service::directory_server { 'simp-pki-ds': * => $ds_config }

  $_cas = deep_merge($cas, $custom_cas)

  simp_pki_service::validate_ca_hash($_cas)

  keys($_cas).each |String $ca_id| {
    if $_cas[$ca_id]['root_ca'] {
      simp_pki_service::ca { $ca_id:
        dirsrv_bind_dn       => $ds_config['root_dn'],
        dirsrv_bind_password => $ds_config['admin_password'],
        *                    => $_cas[$ca_id]
      }

      Simp_pki_service::Directory_server['simp-pki-ds'] -> Simp_pki_service::Ca[$ca_id]
    }
    else {
      simp_pki_service::ca { $ca_id:
        dirsrv_bind_dn                 => $ds_config['root_dn'],
        dirsrv_bind_password           => $ds_config['admin_password'],
        pki_security_domain            => $_cas[$_cas[$ca_id]['parent_ca']]['pki_security_domain'],
        pki_security_domain_user       => $_cas[$_cas[$ca_id]['parent_ca']]['admin_user'],
        pki_security_domain_password   => $_cas[$_cas[$ca_id]['parent_ca']]['admin_password'],
        pki_security_domain_https_port => $_cas[$_cas[$ca_id]['parent_ca']]['https_port'],
        *                              => $_cas[$ca_id],
      }
    }
  }
}
