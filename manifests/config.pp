# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# This class simply provides a protected working directory that persists for
# later CA interaction.
#
# @option generated_config_dir [String]
#   The configuration directory that holds the generated config files
class simp_pki_service::config {

  assert_private()

  # This can't change due to trickle-down ramifications in the defined types
  $generated_config_dir = '/root/.dogtag/generated_configs'

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
