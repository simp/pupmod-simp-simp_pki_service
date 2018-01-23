define simp_pki_service::dogtag::config_item (
  $ca_id,
  $key,
  $value,
  $subsystem => 'ca',
  $file      => 'CS.cfg'
){
  augeas { $name:
    lens    => 'Simplevars.lns',
    incl    => "/var/lib/pki/${ca_id}/${subsystem}/conf/${file}",
    changes => [
      "set ${key} ${value}"
    ],
    require => Simp_pki_service::Ca[$ca_id],
    notify  => Simp_pki_service::Ca::Service[$ca_id]
  }
}
