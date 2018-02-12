# Removes all instances of a given CA and/or CA stack to optionally include the
# 389 Directory Server
#
# @example Completely wipe the default module setup
#   puppet apply -e 'simp_pki_service::destroy { "simp-puppet-pki": }'
#   puppet apply -e 'simp_pki_service::destroy { "simp-site-pki": }'
#   puppet apply -e 'simp_pki_service::destroy { "simp-pki-root": remove_dirsrv => true }'
#
# @option name [String]
#   The server_identifier that you want to remove
#
# @param remove_dirsrv
#   Also remove the module default 389DS installation
#
# @param security_domain
#   The security domain to target
#
define simp_pki_service::destroy (
  $remove_dirsrv = false,
  $security_domain = 'SIMP'
) {

  exec { "Remove ${name} KRA":
    command => "/sbin/pkidestroy -s KRA -i ${name}",
    onlyif  => "/bin/test -d /var/lib/pki/${name}/kra"
  }

  exec { "Remove ${name} CA":
    command => "/sbin/pkidestroy -s CA -i ${name}",
    onlyif  => "/bin/test -d /var/lib/pki/${name}/ca"
  }

  file { "/root/.dogtag/${name}":
    ensure  => 'absent',
    recurse => true,
    force   => true,
    require => Exec["Remove ${name} CA"]
  }

  if $remove_dirsrv {
    exec { 'Remove DS':
      command => '/sbin/remove-ds-admin.pl -a -i slapd-simp-pki-ds || /sbin/remove-ds.pl -a -i slapd-simp-pki-ds',
      onlyif  => '/bin/test -d /var/lib/dirsrv/slapd-simp-pki-ds'
    }
  }
}
