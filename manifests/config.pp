class simp_pki_service::config (
  $generated_config_dir
){
  file { '/root/.dogtag':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0600'
  }

  file { $generated_config_dir:
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    recurse => true,
    purge   => true
  }
}
