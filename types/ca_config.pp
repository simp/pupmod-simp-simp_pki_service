type Simp_pki_service::Ca_config = Hash[ Simp_pki_service::SecurityDomain, Struct[
  {
    'http_port'             => Simplib::Port,
    'https_port'            => Simplib::Port,
    'tomcat_ajp_port'       => Simplib::Port,
    'tomcat_server_port'    => Simplib::Port,
    Optional['root_ca']     => Boolean,
    Optional['enable_scep'] => Boolean,
    Optional['enable_kra']  => Boolean,
    Optional['parent_ca']   => Simp_pki_service::SecurityDomain
  }
]]
