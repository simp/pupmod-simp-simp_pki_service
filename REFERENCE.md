# Reference

<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

### Classes

* [`simp_pki_service`](#simp_pki_service): Creates a single-host Dogtag CA with active sub-CAs
* [`simp_pki_service::config`](#simp_pki_service--config): **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**  This class simply provides a protected w

### Defined types

* [`simp_pki_service::ca`](#simp_pki_service--ca): Set up a Dogtag CA
* [`simp_pki_service::ca::config_item`](#simp_pki_service--ca--config_item): Set a configuration item in a specific CA instance  The ``$subsystem`` and ``$file`` parameters have been pre-set with the most common config
* [`simp_pki_service::ca::service`](#simp_pki_service--ca--service): **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**  Start a CA service on the given p
* [`simp_pki_service::ca::wait_for_service`](#simp_pki_service--ca--wait_for_service): **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**  Wait for the given `timeout` for 
* [`simp_pki_service::destroy`](#simp_pki_service--destroy): Removes all instances of a given CA and/or CA stack to optionally include the 389 Directory Server
* [`simp_pki_service::directory_server`](#simp_pki_service--directory_server): Set up a local 389DS for use by Dogtag
* [`simp_pki_service::directory_server::conf_item`](#simp_pki_service--directory_server--conf_item): Modifies the running directory server configuration and restarts the service when necessary.  **IMPORTANT** Do not set sensitive values with 
* [`simp_pki_service::kra`](#simp_pki_service--kra): **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**  Set up a Dogtag KRA  This should 

### Functions

* [`simp_pki_service::validate_ca_hash`](#simp_pki_service--validate_ca_hash): Validate that the passed Hash of CAs meets the following requirements:  * There is at least one Root CA * Each Sub CA has defined a parent CA

### Data types

* [`Simp_pki_service::Ca::ConfigItemHash`](#Simp_pki_service--Ca--ConfigItemHash): Structure of the 'config_hash' for 'config_item' calls
* [`Simp_pki_service::SecurityDomain`](#Simp_pki_service--SecurityDomain): Allowed Security Domain Text

## Classes

### <a name="simp_pki_service"></a>`simp_pki_service`

Creates a single-host Dogtag CA with active sub-CAs

#### Parameters

The following parameters are available in the `simp_pki_service` class:

* [`pki_security_domain`](#-simp_pki_service--pki_security_domain)
* [`ds_config`](#-simp_pki_service--ds_config)
* [`cas`](#-simp_pki_service--cas)
* [`custom_cas`](#-simp_pki_service--custom_cas)
* [`enable_haveged`](#-simp_pki_service--enable_haveged)

##### <a name="-simp_pki_service--pki_security_domain"></a>`pki_security_domain`

Data type: `Simp_pki_service::SecurityDomain`

A unique name for the security domain for the CA collection

Default value: `'SIMP'`

##### <a name="-simp_pki_service--ds_config"></a>`ds_config`

Data type: `Hash`

Backend 389DS data storage configuration for Dogtag

  * This is passed directly into the ``simp_pki_service::directory_server``
    defined type

Default value:

```puppet
{
    'root_dn'        => "cn=${pki_security_domain} Directory Manager",
    'base_dn'        => sprintf('ou=%s,%s',$pki_security_domain, simplib::ldap::domain_to_dn($facts['networking']['domain'], false)),
    'admin_password' => simplib::passgen('389-ds-simp-pki', {'length' => 64, 'complexity' => 0 })
  }
```

##### <a name="-simp_pki_service--cas"></a>`cas`

Data type: `Hash[String[1], Hash]`

A Hash of CA entries that are passed directly into the
``simp_pki_service::ca`` defined type

* Hash keys are the parameters in ``simp_pki_service::ca``
* Nested Sub CAs are currently not supported

Default value:

```puppet
{
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
  }
```

##### <a name="-simp_pki_service--custom_cas"></a>`custom_cas`

Data type: `Hash[String[1], Hash]`

A user-provided Hash of additional CA entries that are passed directly into
the ``simp_pki_service::ca`` defined type

  * NOTE: These will be **deep merged** into the regular ``$cas`` parameter

Default value: `{}`

##### <a name="-simp_pki_service--enable_haveged"></a>`enable_haveged`

Data type: `Boolean`

Enable the HAVEGEd entropy collection daemon

Default value: `simplib::lookup('simp_options::haveged', { 'default_value'  => true })`

### <a name="simp_pki_service--config"></a>`simp_pki_service::config`

**NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**

This class simply provides a protected working directory that persists for
later CA interaction.

## Defined types

### <a name="simp_pki_service--ca"></a>`simp_pki_service::ca`

Set up a Dogtag CA

#### Parameters

The following parameters are available in the `simp_pki_service::ca` defined type:

* [`http_port`](#-simp_pki_service--ca--http_port)
* [`https_port`](#-simp_pki_service--ca--https_port)
* [`tomcat_ajp_port`](#-simp_pki_service--ca--tomcat_ajp_port)
* [`tomcat_server_port`](#-simp_pki_service--ca--tomcat_server_port)
* [`dirsrv_bind_dn`](#-simp_pki_service--ca--dirsrv_bind_dn)
* [`dirsrv_bind_password`](#-simp_pki_service--ca--dirsrv_bind_password)
* [`pki_security_domain`](#-simp_pki_service--ca--pki_security_domain)
* [`admin_user`](#-simp_pki_service--ca--admin_user)
* [`admin_password`](#-simp_pki_service--ca--admin_password)
* [`pki_security_domain_hostname`](#-simp_pki_service--ca--pki_security_domain_hostname)
* [`pki_security_domain_https_port`](#-simp_pki_service--ca--pki_security_domain_https_port)
* [`root_ca`](#-simp_pki_service--ca--root_ca)
* [`pki_security_domain_user`](#-simp_pki_service--ca--pki_security_domain_user)
* [`pki_security_domain_password`](#-simp_pki_service--ca--pki_security_domain_password)
* [`create_subordinate_security_domain`](#-simp_pki_service--ca--create_subordinate_security_domain)
* [`enable_kra`](#-simp_pki_service--ca--enable_kra)
* [`parent_ca`](#-simp_pki_service--ca--parent_ca)
* [`ca_config`](#-simp_pki_service--ca--ca_config)
* [`kra_config`](#-simp_pki_service--ca--kra_config)
* [`scep_profile_config`](#-simp_pki_service--ca--scep_profile_config)
* [`debug_level`](#-simp_pki_service--ca--debug_level)
* [`service_timeout`](#-simp_pki_service--ca--service_timeout)
* [`package_ensure`](#-simp_pki_service--ca--package_ensure)

##### <a name="-simp_pki_service--ca--http_port"></a>`http_port`

Data type: `Simplib::Port`

The insecure port

##### <a name="-simp_pki_service--ca--https_port"></a>`https_port`

Data type: `Simplib::Port`

The secure port

##### <a name="-simp_pki_service--ca--tomcat_ajp_port"></a>`tomcat_ajp_port`

Data type: `Simplib::Port`

The Apache JServ Protocol port

##### <a name="-simp_pki_service--ca--tomcat_server_port"></a>`tomcat_server_port`

Data type: `Simplib::Port`

Port used to shutdown Tomcat

##### <a name="-simp_pki_service--ca--dirsrv_bind_dn"></a>`dirsrv_bind_dn`

Data type: `String[2]`

The bind_dn for 389DS

  * Note: This is probably your root DN

##### <a name="-simp_pki_service--ca--dirsrv_bind_password"></a>`dirsrv_bind_password`

Data type: `String[1]`

The password for ``dirsrv_bind_dn``

##### <a name="-simp_pki_service--ca--pki_security_domain"></a>`pki_security_domain`

Data type: `Simp_pki_service::SecurityDomain`

The Security Domain for your CA

  * It is **highly recommended** that you keep groups of related CAs in the
    same security domain for this module

##### <a name="-simp_pki_service--ca--admin_user"></a>`admin_user`

Data type: `String[2]`

The CA administrative user

Default value: `'caadmin'`

##### <a name="-simp_pki_service--ca--admin_password"></a>`admin_password`

Data type: `String[1]`

The password for the CA administrative user

Default value: `simplib::passgen("${pki_security_domain}_${name}", { 'length' => 64, 'complexity' => 0 })`

##### <a name="-simp_pki_service--ca--pki_security_domain_hostname"></a>`pki_security_domain_hostname`

Data type: `Simplib::Hostname`

The hostname for the root CA for ``$pki_security_domain``

Default value: `$facts['networking']['fqdn']`

##### <a name="-simp_pki_service--ca--pki_security_domain_https_port"></a>`pki_security_domain_https_port`

Data type: `Simplib::Port`

The secure port for the root CA for ``$pki_security_domain``

Default value: `8443`

##### <a name="-simp_pki_service--ca--root_ca"></a>`root_ca`

Data type: `Boolean`

Set if this CA is a root

Default value: `false`

##### <a name="-simp_pki_service--ca--pki_security_domain_user"></a>`pki_security_domain_user`

Data type: `String[2]`

The administrative username for the root CA for ``$pki_security_domain``

Default value: `$admin_user`

##### <a name="-simp_pki_service--ca--pki_security_domain_password"></a>`pki_security_domain_password`

Data type: `String[1]`

The administrative password for the root CA for ``$pki_security_domain``

Default value: `$admin_password`

##### <a name="-simp_pki_service--ca--create_subordinate_security_domain"></a>`create_subordinate_security_domain`

Data type: `Boolean`

Add a separate subordinate security domain for this CA

  * Note: Has no effect if ``$root_ca`` is ``true``

Default value: `false`

##### <a name="-simp_pki_service--ca--enable_kra"></a>`enable_kra`

Data type: `Boolean`

Enable the KRA subsystem for this CA

Default value: `false`

##### <a name="-simp_pki_service--ca--parent_ca"></a>`parent_ca`

Data type: `Optional[String[1]]`

The root CA for this CA

  * Should not be set if this system is a root CA

Default value: `undef`

##### <a name="-simp_pki_service--ca--ca_config"></a>`ca_config`

Data type: `Hash`

A 'one-to-one' configuration Hash for the CA

* Each `key`/`value` pair is directly mapped into the CA's `CS.cfg` file
  without type checking
* For example, to enable the SCEP responder, you would set `ca.scep.enable`
  to `true`

Default value: `{}`

##### <a name="-simp_pki_service--ca--kra_config"></a>`kra_config`

Data type: `Hash`

A 'one-to-one' configuration Hash for the KRA

* Each `key`/`value` pair is directly mapped into the KRA's `CS.cfg` file
  without type checking

Default value: `{}`

##### <a name="-simp_pki_service--ca--scep_profile_config"></a>`scep_profile_config`

Data type: `Hash`

A 'one-to-one' configuration Hash that will udpdate the values in the 'caRouterCert.cfg'

* Each `key`/`value` pair is directly mapped into the CA's caRouterCert.cfg
  profile file since this is hard coded for SCEP use.
* No validity checking is performed.

Default value:

```puppet
{
    'desc'                                                                 => 'This certificate profile is for enrolling server certificates via SCEP.',
    'name'                                                                 => 'One Time Pin Server Certificate Enrollment',
    'policyset.serverCertSet.6.constraint.params.keyUsageDataEncipherment' => true,
    'policyset.serverCertSet.6.default.params.keyUsageDataEncipherment'    => true,
    'policyset.serverCertSet.7.default.params.exKeyUsageOIDs'              => ['1.3.6.1.5.5.7.3.1','1.3.6.1.5.5.7.3.2','1.3.6.1.5.5.7.3.4']
  }
```

##### <a name="-simp_pki_service--ca--debug_level"></a>`debug_level`

Data type: `Integer[0,10]`

Set the debug level of the CA and KRA

  * 10 => off
  * 0  => highest level of debugging

Default value: `10`

##### <a name="-simp_pki_service--ca--service_timeout"></a>`service_timeout`

Data type: `Integer[1]`

The number of seconds to wait for the service to listen on `http_port`

Default value: `5`

##### <a name="-simp_pki_service--ca--package_ensure"></a>`package_ensure`

Data type: `Simplib::PackageEnsure`

What to do regarding package installation

Default value: `simplib::lookup('simp_options::package_ensure', { 'default_value'  => 'installed' })`

### <a name="simp_pki_service--ca--config_item"></a>`simp_pki_service::ca::config_item`

Set a configuration item in a specific CA instance

The ``$subsystem`` and ``$file`` parameters have been pre-set with the most
common configuration target.

#### Parameters

The following parameters are available in the `simp_pki_service::ca::config_item` defined type:

* [`ca_id`](#-simp_pki_service--ca--config_item--ca_id)
* [`port`](#-simp_pki_service--ca--config_item--port)
* [`timeout`](#-simp_pki_service--ca--config_item--timeout)
* [`key`](#-simp_pki_service--ca--config_item--key)
* [`value`](#-simp_pki_service--ca--config_item--value)
* [`config_hash`](#-simp_pki_service--ca--config_item--config_hash)
* [`value_join`](#-simp_pki_service--ca--config_item--value_join)
* [`subsystem`](#-simp_pki_service--ca--config_item--subsystem)
* [`file`](#-simp_pki_service--ca--config_item--file)
* [`target`](#-simp_pki_service--ca--config_item--target)

##### <a name="-simp_pki_service--ca--config_item--ca_id"></a>`ca_id`

Data type: `String[1]`

The ID (name) of the CA that you will be modifying

##### <a name="-simp_pki_service--ca--config_item--port"></a>`port`

Data type: `Simplib::Port`

The port upon which the service should be listening

* Used to validate that the service is active

##### <a name="-simp_pki_service--ca--config_item--timeout"></a>`timeout`

Data type: `Integer[1]`

How long to wait, in seconds, for the service to start listening

Default value: `5`

##### <a name="-simp_pki_service--ca--config_item--key"></a>`key`

Data type: `Optional[String[1]]`

The 'key' that you want to set in the configuration file

* You can set either `config_hash` OR `key` and `value`, but not both
* Must be set if `value` is set

Default value: `undef`

##### <a name="-simp_pki_service--ca--config_item--value"></a>`value`

Data type: `Optional[Variant[String[1], Boolean, Numeric]]`

The 'value' to which to set the ``$key`` in the configuration file

* You can set either `config_hash` OR `key` and `value`, but not both
* Must be set if `key` is set

Default value: `undef`

##### <a name="-simp_pki_service--ca--config_item--config_hash"></a>`config_hash`

Data type: `Simp_pki_service::Ca::ConfigItemHash`

A Hash of key/value pairs that should be added to the system

* You can set either `config_hash` OR `key` and `value`, but not both

Default value: `{}`

##### <a name="-simp_pki_service--ca--config_item--value_join"></a>`value_join`

Data type: `String[1]`

If the `value` is an `Array`, this `String` will be used to join the
elements

Default value: `','`

##### <a name="-simp_pki_service--ca--config_item--subsystem"></a>`subsystem`

Data type: `String[1]`

The Dogtag Subsystem that is to be managed (lower case)

* Has no effect if `target` is set

Default value: `'ca'`

##### <a name="-simp_pki_service--ca--config_item--file"></a>`file`

Data type: `String[1]`

The specific configuration file to update

* Has no effect if `target` is set

Default value: `'CS.cfg'`

##### <a name="-simp_pki_service--ca--config_item--target"></a>`target`

Data type: `Optional[Stdlib::AbsolutePath]`

The full path to the target file

Default value: `undef`

### <a name="simp_pki_service--ca--service"></a>`simp_pki_service::ca::service`

**NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**

Start a CA service on the given port and wait until the service has
successfully started or the timeout is reached.

#### Parameters

The following parameters are available in the `simp_pki_service::ca::service` defined type:

* [`port`](#-simp_pki_service--ca--service--port)
* [`timeout`](#-simp_pki_service--ca--service--timeout)

##### <a name="-simp_pki_service--ca--service--port"></a>`port`

Data type: `Simplib::Port`

The port upon which to listen

##### <a name="-simp_pki_service--ca--service--timeout"></a>`timeout`

Data type: `Integer[1]`

How long to wait, in seconds, for the daemon to start

Default value: `5`

### <a name="simp_pki_service--ca--wait_for_service"></a>`simp_pki_service::ca::wait_for_service`

**NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**

Wait for the given `timeout` for the service on `port` to start.

This is present because the Dogtag services will return that they are fully
functional prior to actually listening on a port.

#### Parameters

The following parameters are available in the `simp_pki_service::ca::wait_for_service` defined type:

* [`port`](#-simp_pki_service--ca--wait_for_service--port)
* [`timeout`](#-simp_pki_service--ca--wait_for_service--timeout)

##### <a name="-simp_pki_service--ca--wait_for_service--port"></a>`port`

Data type: `Simplib::Port`

The port upon which to listen

##### <a name="-simp_pki_service--ca--wait_for_service--timeout"></a>`timeout`

Data type: `Integer[1]`

How long to wait, in seconds, for the daemon to start listening

Default value: `5`

### <a name="simp_pki_service--destroy"></a>`simp_pki_service::destroy`

Removes all instances of a given CA and/or CA stack to optionally include the
389 Directory Server

#### Examples

##### Completely wipe the default module setup

```puppet
puppet apply -e 'simp_pki_service::destroy { "simp-puppet-pki": }'
puppet apply -e 'simp_pki_service::destroy { "simp-site-pki": }'
puppet apply -e 'simp_pki_service::destroy { "simp-pki-root": remove_dirsrv => true }'
```

#### Parameters

The following parameters are available in the `simp_pki_service::destroy` defined type:

* [`remove_dirsrv`](#-simp_pki_service--destroy--remove_dirsrv)
* [`security_domain`](#-simp_pki_service--destroy--security_domain)

##### <a name="-simp_pki_service--destroy--remove_dirsrv"></a>`remove_dirsrv`

Data type: `Any`

Also remove the module default 389DS installation

Default value: `false`

##### <a name="-simp_pki_service--destroy--security_domain"></a>`security_domain`

Data type: `Any`

The security domain to target

Default value: `'SIMP'`

### <a name="simp_pki_service--directory_server"></a>`simp_pki_service::directory_server`

Set up a local 389DS for use by Dogtag

#### Parameters

The following parameters are available in the `simp_pki_service::directory_server` defined type:

* [`base_dn`](#-simp_pki_service--directory_server--base_dn)
* [`root_dn`](#-simp_pki_service--directory_server--root_dn)
* [`admin_password`](#-simp_pki_service--directory_server--admin_password)
* [`listen_address`](#-simp_pki_service--directory_server--listen_address)
* [`port`](#-simp_pki_service--directory_server--port)
* [`enable_admin_service`](#-simp_pki_service--directory_server--enable_admin_service)
* [`admin_user`](#-simp_pki_service--directory_server--admin_user)
* [`admin_service_listen_address`](#-simp_pki_service--directory_server--admin_service_listen_address)
* [`admin_service_port`](#-simp_pki_service--directory_server--admin_service_port)
* [`service_user`](#-simp_pki_service--directory_server--service_user)
* [`service_group`](#-simp_pki_service--directory_server--service_group)
* [`package_ensure`](#-simp_pki_service--directory_server--package_ensure)

##### <a name="-simp_pki_service--directory_server--base_dn"></a>`base_dn`

Data type: `String[2]`

The 'base' DN component of the directory server

##### <a name="-simp_pki_service--directory_server--root_dn"></a>`root_dn`

Data type: `String[2]`

The default administrator DN for the directory server

##### <a name="-simp_pki_service--directory_server--admin_password"></a>`admin_password`

Data type: `String[2]`

The password for the ``$admin_user`` and the ``$root_dn``

Default value: `simplib::passgen("389-ds-${name}", { 'length' => 64, 'complexity' => 0 })`

##### <a name="-simp_pki_service--directory_server--listen_address"></a>`listen_address`

Data type: `Simplib::IP`

The IP address upon which to listen

Default value: `'127.0.0.1'`

##### <a name="-simp_pki_service--directory_server--port"></a>`port`

Data type: `Simplib::Port`

The port upon which to accept connections

Default value: `389`

##### <a name="-simp_pki_service--directory_server--enable_admin_service"></a>`enable_admin_service`

Data type: `Boolean`

Enable the administrative interface for the GUI

Default value: `false`

##### <a name="-simp_pki_service--directory_server--admin_user"></a>`admin_user`

Data type: `String[2]`

The administrative user for administrative GUI connections

Default value: `'admin'`

##### <a name="-simp_pki_service--directory_server--admin_service_listen_address"></a>`admin_service_listen_address`

Data type: `Simplib::IP`

The IP address upon which the administrative interface should listen

Default value: `'0.0.0.0'`

##### <a name="-simp_pki_service--directory_server--admin_service_port"></a>`admin_service_port`

Data type: `Simplib::Port`

The port upon which the administrative interface should listen

Default value: `9830`

##### <a name="-simp_pki_service--directory_server--service_user"></a>`service_user`

Data type: `String[1]`

The user that ``389ds`` should run as

Default value: `'nobody'`

##### <a name="-simp_pki_service--directory_server--service_group"></a>`service_group`

Data type: `String[1]`

The group that ``389ds`` should run as

Default value: `'nobody'`

##### <a name="-simp_pki_service--directory_server--package_ensure"></a>`package_ensure`

Data type: `Simplib::PackageEnsure`

What to do regarding package installation

Default value: `simplib::lookup('simp_options::package_ensure', { 'default_value'  => 'installed' })`

### <a name="simp_pki_service--directory_server--conf_item"></a>`simp_pki_service::directory_server::conf_item`

Modifies the running directory server configuration and restarts the service
when necessary.

**IMPORTANT** Do not set sensitive values with this until it switches over to
being a native type!

#### Parameters

The following parameters are available in the `simp_pki_service::directory_server::conf_item` defined type:

* [`key`](#-simp_pki_service--directory_server--conf_item--key)
* [`value`](#-simp_pki_service--directory_server--conf_item--value)
* [`admin_dn`](#-simp_pki_service--directory_server--conf_item--admin_dn)
* [`pw_file`](#-simp_pki_service--directory_server--conf_item--pw_file)
* [`ds_service_name`](#-simp_pki_service--directory_server--conf_item--ds_service_name)
* [`restart_service`](#-simp_pki_service--directory_server--conf_item--restart_service)
* [`ds_host`](#-simp_pki_service--directory_server--conf_item--ds_host)
* [`ds_port`](#-simp_pki_service--directory_server--conf_item--ds_port)
* [`base_dn`](#-simp_pki_service--directory_server--conf_item--base_dn)

##### <a name="-simp_pki_service--directory_server--conf_item--key"></a>`key`

Data type: `Any`

The configuration key to be set

  * You can get a list of all configuration keys by running:
    ``ldapsearch -H ldap://localhost:389 -y $HOME/.dogtag/generated_configs/ds_pw.txt \
    -D "cn=SIMP Directory Manager" -s base -b "cn=config"``

##### <a name="-simp_pki_service--directory_server--conf_item--value"></a>`value`

Data type: `Any`

The value that should be set for ``$key``

##### <a name="-simp_pki_service--directory_server--conf_item--admin_dn"></a>`admin_dn`

Data type: `Any`

A DN with administrative rights to the directory

##### <a name="-simp_pki_service--directory_server--conf_item--pw_file"></a>`pw_file`

Data type: `Any`

A file containing the password for use with ``$admin_dn``

##### <a name="-simp_pki_service--directory_server--conf_item--ds_service_name"></a>`ds_service_name`

Data type: `Any`

The Puppet resource name for the directory ``Service`` resource

##### <a name="-simp_pki_service--directory_server--conf_item--restart_service"></a>`restart_service`

Data type: `Any`

Whether or not to restart the directory server after applying this item

  * There is a known list of items in the module data that will always
    generate a restart action

Default value: `false`

##### <a name="-simp_pki_service--directory_server--conf_item--ds_host"></a>`ds_host`

Data type: `Any`

The host where the service is running

Default value: `'127.0.0.1'`

##### <a name="-simp_pki_service--directory_server--conf_item--ds_port"></a>`ds_port`

Data type: `Any`

The port to which to connect

Default value: `'389'`

##### <a name="-simp_pki_service--directory_server--conf_item--base_dn"></a>`base_dn`

Data type: `Any`

The DN that holds the directory configuration items

Default value: `'cn=config'`

### <a name="simp_pki_service--kra"></a>`simp_pki_service::kra`

**NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINED TYPE**

Set up a Dogtag KRA

This should only be called from the ``simp_pki_service::ca`` define. Doing
otherwise may work but is an untested configuration.

#### Parameters

The following parameters are available in the `simp_pki_service::kra` defined type:

* [`http_port`](#-simp_pki_service--kra--http_port)
* [`https_port`](#-simp_pki_service--kra--https_port)
* [`tomcat_ajp_port`](#-simp_pki_service--kra--tomcat_ajp_port)
* [`tomcat_server_port`](#-simp_pki_service--kra--tomcat_server_port)
* [`dirsrv_bind_dn`](#-simp_pki_service--kra--dirsrv_bind_dn)
* [`dirsrv_bind_password`](#-simp_pki_service--kra--dirsrv_bind_password)
* [`pki_security_domain`](#-simp_pki_service--kra--pki_security_domain)
* [`pki_security_domain_user`](#-simp_pki_service--kra--pki_security_domain_user)
* [`pki_security_domain_password`](#-simp_pki_service--kra--pki_security_domain_password)
* [`pki_security_domain_hostname`](#-simp_pki_service--kra--pki_security_domain_hostname)
* [`pki_security_domain_https_port`](#-simp_pki_service--kra--pki_security_domain_https_port)
* [`admin_password`](#-simp_pki_service--kra--admin_password)
* [`ca_hostname`](#-simp_pki_service--kra--ca_hostname)
* [`ca_port`](#-simp_pki_service--kra--ca_port)
* [`admin_user`](#-simp_pki_service--kra--admin_user)
* [`kra_config`](#-simp_pki_service--kra--kra_config)
* [`service_timeout`](#-simp_pki_service--kra--service_timeout)
* [`package_ensure`](#-simp_pki_service--kra--package_ensure)

##### <a name="-simp_pki_service--kra--http_port"></a>`http_port`

Data type: `Simplib::Port`

The insecure port

##### <a name="-simp_pki_service--kra--https_port"></a>`https_port`

Data type: `Simplib::Port`

The secure port

##### <a name="-simp_pki_service--kra--tomcat_ajp_port"></a>`tomcat_ajp_port`

Data type: `Simplib::Port`

The Apache JServ Protocol port

##### <a name="-simp_pki_service--kra--tomcat_server_port"></a>`tomcat_server_port`

Data type: `Simplib::Port`

Port used to shutdown Tomcat

##### <a name="-simp_pki_service--kra--dirsrv_bind_dn"></a>`dirsrv_bind_dn`

Data type: `String[2]`

The bind_dn for 389DS

##### <a name="-simp_pki_service--kra--dirsrv_bind_password"></a>`dirsrv_bind_password`

Data type: `String[1]`

The password for ``dirsrv_bind_dn``

##### <a name="-simp_pki_service--kra--pki_security_domain"></a>`pki_security_domain`

Data type: `Simp_pki_service::SecurityDomain`

The Security Domain for your KRA

  * It is **highly recommended** that you keep groups of related CAs in the
    same security domain for this module.

##### <a name="-simp_pki_service--kra--pki_security_domain_user"></a>`pki_security_domain_user`

Data type: `String[2]`

The administrative username for the root CA for ``$pki_security_domain``

##### <a name="-simp_pki_service--kra--pki_security_domain_password"></a>`pki_security_domain_password`

Data type: `String[2]`

The administrative password for the root CA for ``$pki_security_domain``

##### <a name="-simp_pki_service--kra--pki_security_domain_hostname"></a>`pki_security_domain_hostname`

Data type: `Simplib::Hostname`

The hostname for the root CA for ``$pki_security_domain``

##### <a name="-simp_pki_service--kra--pki_security_domain_https_port"></a>`pki_security_domain_https_port`

Data type: `Simplib::Port`

The secure port for the root CA for ``$pki_security_domain``

##### <a name="-simp_pki_service--kra--admin_password"></a>`admin_password`

Data type: `String[1]`

The password for the CA administrative user specified in ``$admin_user``

##### <a name="-simp_pki_service--kra--ca_hostname"></a>`ca_hostname`

Data type: `Simplib::Hostname`

The hostname of the CA that this KRA is bound to

##### <a name="-simp_pki_service--kra--ca_port"></a>`ca_port`

Data type: `Simplib::Port`

The port of the CA that this KRA is bound to

##### <a name="-simp_pki_service--kra--admin_user"></a>`admin_user`

Data type: `String[1]`

The administrative user of the CA that this KRA is bound to

Default value: `'caadmin'`

##### <a name="-simp_pki_service--kra--kra_config"></a>`kra_config`

Data type: `Hash`

A `key`/`value` pair set that will be fed directly into the KRA `CS.cfg`

Default value: `{}`

##### <a name="-simp_pki_service--kra--service_timeout"></a>`service_timeout`

Data type: `Integer[1]`

The number of seconds to wait for the service to listen on `http_port`

Default value: `5`

##### <a name="-simp_pki_service--kra--package_ensure"></a>`package_ensure`

Data type: `Simplib::PackageEnsure`

What to do regarding package installation

Default value: `simplib::lookup('simp_options::package_ensure', { 'default_value'  => 'installed' })`

## Functions

### <a name="simp_pki_service--validate_ca_hash"></a>`simp_pki_service::validate_ca_hash`

Type: Ruby 4.x API

Validate that the passed Hash of CAs meets the following requirements:

* There is at least one Root CA
* Each Sub CA has defined a parent CA
* Each Sub CA is bound to a Root CA (nested Sub CAs are not supported)

The CA hashes are a one-to-one mapping to the parameters in
``simp_pki_service::ca``.

This does **not** check that all options for each CA are valid, that is left
to the defined types to which the hash components are passed.

**Compilation will be terminated if validation fails**

#### Examples

##### Missing Root CA Failure

```puppet

$ca_hash = {
  'sub_ca' => {
    'root_ca'   => false,
    'parent_ca' => 'unknown-ca'
  }
}
simp_pki_service::validate_ca_hash($ca_hash)
```

##### No Parent CA Defined Failure

```puppet

$ca_hash = {
  'pki-root' => {
    'root_ca' => true
  },
  'pki-sub' => {
    'root_ca'   => false
  }
}
simp_pki_service::validate_ca_hash($ca_hash)
```

##### Missing Parent Root CA Failure

```puppet

$ca_hash = {
  'pki-root' => {
    'root_ca' => true
  },
  'pki-sub' => {
    'root_ca'   => false,
    'parent_ca' => 'missing-ca'
  }
}
simp_pki_service::validate_ca_hash($ca_hash)
```

##### Valid Hash

```puppet

$ca_hash = {
  'pki-root' => {
    'root_ca' => true
  },
  'pki-sub' => {
    'root_ca'   => false,
    'parent_ca' => 'pki-root'
  }
}
simp_pki_service::validate_ca_hash($ca_hash)
```

#### `simp_pki_service::validate_ca_hash(Hash[String[1], Hash] $ca_hash)`

Validate that the passed Hash of CAs meets the following requirements:

* There is at least one Root CA
* Each Sub CA has defined a parent CA
* Each Sub CA is bound to a Root CA (nested Sub CAs are not supported)

The CA hashes are a one-to-one mapping to the parameters in
``simp_pki_service::ca``.

This does **not** check that all options for each CA are valid, that is left
to the defined types to which the hash components are passed.

**Compilation will be terminated if validation fails**

Returns: `None`

Raises:

* `RuntimeError` if validation fails

##### Examples

###### Missing Root CA Failure

```puppet

$ca_hash = {
  'sub_ca' => {
    'root_ca'   => false,
    'parent_ca' => 'unknown-ca'
  }
}
simp_pki_service::validate_ca_hash($ca_hash)
```

###### No Parent CA Defined Failure

```puppet

$ca_hash = {
  'pki-root' => {
    'root_ca' => true
  },
  'pki-sub' => {
    'root_ca'   => false
  }
}
simp_pki_service::validate_ca_hash($ca_hash)
```

###### Missing Parent Root CA Failure

```puppet

$ca_hash = {
  'pki-root' => {
    'root_ca' => true
  },
  'pki-sub' => {
    'root_ca'   => false,
    'parent_ca' => 'missing-ca'
  }
}
simp_pki_service::validate_ca_hash($ca_hash)
```

###### Valid Hash

```puppet

$ca_hash = {
  'pki-root' => {
    'root_ca' => true
  },
  'pki-sub' => {
    'root_ca'   => false,
    'parent_ca' => 'pki-root'
  }
}
simp_pki_service::validate_ca_hash($ca_hash)
```

##### `ca_hash`

Data type: `Hash[String[1], Hash]`

The CA Hash to process

## Data types

### <a name="Simp_pki_service--Ca--ConfigItemHash"></a>`Simp_pki_service::Ca::ConfigItemHash`

Structure of the 'config_hash' for 'config_item' calls

Alias of

```puppet
Hash[String[1], Variant[
    String[1],
    Boolean,
    Numeric,
    Array[String[1]
    ]
  ]]
```

### <a name="Simp_pki_service--SecurityDomain"></a>`Simp_pki_service::SecurityDomain`

Allowed Security Domain Text

Alias of `Pattern['^(\w|\-)+$']`

