# $name is the server_identifier that you want to remove
# 'pki-simp' is the module default
define simp_pki_service::destroy (
  $remove_dirsrv = false,
  $security_domain = 'SIMP',
  $security_domain_passfile = "/root/.dogtag/${name}/ca/pkcs12_password.conf"
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
      command => "/sbin/remove-ds-admin.pl -a -i slapd-simp-pki-ds || /sbin/remove-ds.pl -a -i slapd-simp-pki-ds",
      onlyif  => "/bin/test -d /var/lib/dirsrv/slapd-simp-pki-ds"
    }
  }
}
