[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/simp_pki_service.svg)](https://forge.puppetlabs.com/simp/simp_pki_service)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/simp_pki_service.svg)](https://forge.puppetlabs.com/simp/simp_pki_service)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_pki_service.svg)](https://travis-ci.org/simp/pupmod-simp-simp_pki_service)


---

    +--------------------------------------------------------------+
    | WARNING: This is currently an **EXPERIMENTAL** module things |
    | may change drastically, and in breaking ways, without notice!|
    +--------------------------------------------------------------+

---

## This is a SIMP module

This module is a component of the
[System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they can be submitted to our
[JIRA](https://simp-project.atlassian.net/).

## Module Description

*simp/simp_pki_service* is a SIMP-oriented installation of the
[Dogtag Certificate System](http://pki.fedoraproject.org/wiki/PKI_Main_Page).

Traditionally, SIMP has used an internal "FakeCA" `openssl`-based CA. Over
time, this has proven insufficient for our needs, particularly for capabilities
in terms of Key Enrollment (SCEP and CMC), OCSP, and overall management of
certificates.

Additionally, we found that many users wanted to adjust the certificate
parameters for the Puppet subsystem itself outside of the defaults and/or use a
"real", and more scalable CA system for all certificate management.

Dogtag was selected since it was likely to be the most familiar to any users of
the [FreeIPA](https://www.freeipa.org/page/Main_Page) or
[Red Hat Identity Management](https://access.redhat.com/products/identity-management)
product suite and should allow for transition from one to the other in a
vendor supported manner.

## Setup

### What simp_pki_service affects

This module sets up the following components on your system:

  * Internal [389ds](http://directory.fedoraproject.org/) Directory Server
    * Bound to `127.0.0.1` only to restrict access

  * Dogtag with the following subsystems:
    * Root CA -> `simp-pki-root`
    * Sub CA with KRA and SCEP -> `simp-puppet-pki`
    * Sub CA with KRA and SCEP -> `simp-site-pki`

### Setup Requirements

Due to the high entropy requirements, systems will need to be able to install
the `haveged` package from the `EPEL` repository.

The creation of the PKI infrastructure is **extremely** CPU intensive. Once
created, individual actions are not too burdensome on the system. At a minimum,
the system should have:

  * 2 CPUs
    * These **will** be completely utilized during setup
  * 512MB RAM Free

## Usage

### Installation

To install the CA system, you simply need to include the `simp_pki_service`
class on your node. This will instantiate the services as follows:

```
                  +----------------+
                  |                |
                  |  simp-pki-root |
                  |   Port: 4509   |
                  |                |
                  +----------------+
                          |
           ---------------+---------------
          /                               \
         v                                 v
+-----------------+                +---------------+
|                 |                |               |
| simp-puppet-pki |                | simp-site-pki |
|   Port: 5509    |                |  Port: 8443   |
|                 |                |               |
+-----------------+                +---------------+

```

The CA and subordinate CA configuration shown above is controlled by the
`simp_pki_service::cas` parameter. You can change the settings, including the
bound ports, for the default infrastructure by manipulating this data hash.
However, **once the system is active you CANNOT change the ports or hostname**
since the OCSP information is usually incorporated into all signed certificates
and will then be invalid.

If you wish to customize the existing CA settings, or add your own CAs to the
mix, you can easily do this using the `simp_pki_service::custom_cas` parameter.
This hash will be combined with `simp_pki_service::cas` using a `deep_merge` to
allow for full customization.

### The simp-pki-root CA

This CA is the root for all subordinate CAs and should never be exposed outside
of the local system unless it is specifically to an off-system subordinate CA.

If this CA is compromised, then all subordinate CAs are now invalid and must be
replaced, additionally, when this CA expires, all subordinate CAs must be
regenerated.

### The simp-puppet-pki subordinate CA

This CA is the new root for all `puppet` operations in the infrastructure. The
goal of this is that the `puppet` CA will no longer be used and certificates
from this new CA will be used in place of the traditional `puppet` certificates
in accordance with the
[External CA Support](https://puppet.com/docs/puppet/latest/config_ssl_external_ca.html)
documentation from Puppet, Inc.

### The simp-site-pki subordinate CA

This CA replaces the SIMP `FakeCA` for general purpose internal certificate
generation and maintenance. It is meant to be used with `certmonger`, or
another automated enrollment utility but can also be used to generate
certificates and ship them using the `simp-pki` puppet module in the same way
that the `FakeCA` was traditionally used.

**NOTE:** This has been pinned to port `8443` by default since it is the
default `dogtag` port and the most likely to be allowed through firewalls by
default.

### The `/root/.dogtag` Directory

This directory holds all configuration and maintenance information and
credentials for the various CAs that have been set up on the system.

    /root/.dogtag
    ├── generated_configs                   <- Puppet Generated Files
    │   ├── dogtag_simp-pki-root_ca.cfg
    │   ├── dogtag_simp-puppet-pki_ca.cfg
    │   ├── dogtag_simp-puppet-pki_kra.cfg
    │   ├── dogtag_simp-site-pki_ca.cfg
    │   ├── dogtag_simp-site-pki_kra.cfg
    │   ├── ds_pw.txt                       <- Directory Server Password
    │   └── ds_simp-pki-ds_setup.inf
    ├── simp-pki-root
    │   ├── ca
    │   │   ├── alias                       <- NSSDB for Root PKI
    │   │   ├── password.conf               <- Password for Root PKI
    │   │   └── pkcs12_password.conf
    │   ├── ca_admin.cert
    │   ├── ca_admin.cert.der
    │   └── ca_admin_cert.p12
    ├── simp-puppet-pki
    │   ├── ca
    │   │   ├── alias                       <- NSSDB for Puppet Sub PKI
    │   │   ├── password.conf               <- Password for Puppet Sub PKI
    │   │   └── pkcs12_password.conf
    │   ├── ca_admin.cert
    │   ├── ca_admin.cert.der
    │   └── ca_admin_cert.p12
    └── simp-site-pki
        ├── ca
        │   ├── alias                       <- NSSDB for Site Sub PKI
        │   ├── password.conf               <- Password for Site Sub PKI
        │   └── pkcs12_password.conf
        ├── ca_admin.cert
        ├── ca_admin.cert.der
        └── ca_admin_cert.p12

### CLI CA Control

The `pki` subsystem has a great number of
[command line options](http://pki.fedoraproject.org/wiki/PKI_CLI) that may be
used to interact with the different subsystems. There is also a
[server CLI interface](http://pki.fedoraproject.org/wiki/PKI_Server_Instance_CLI)
but we recommend using the standard remote CLI so that you know if the remote
connections are working properly.

#### BASH aliases

---

**IMPORTANT: DO NOT SKIP THIS SECTION**

---

The following aliases are recommended to be added to the `root` user's
`$HOME/.bashrc` file to make daily interaction with the different systems as
easy as possible:

```bash
# This will be your most commonly used command

alias site-pki-base='pki -d $HOME/.dogtag/simp-site-pki/ca/alias -C $HOME/.dogtag/simp-site-pki/ca/password.conf'
alias site-pki='site-pki-base -n "caadmin" -P https -p 8443'

# This should only be used for Puppet ecosystem certificates:
# For example: puppetserver, puppetdb, puppet agent

alias puppet-pki-base='pki -d $HOME/.dogtag/simp-puppet-pki/ca/alias -C $HOME/.dogtag/simp-puppet-pki/ca/password.conf'
alias puppet-pki='puppet-pki-base -n "caadmin" -P https -p 5509'

# This will rarely be used and controls the *root* CA
# If you invalidate or break the root CA, everything below it will need to be
# regenerated!

alias pki-root-base='pki -d $HOME/.dogtag/simp-pki-root/ca/alias -C $HOME/.dogtag/simp-pki-root/ca/password.conf'
alias pki-root='pki-root-base -n "caadmin" -P https -p 4509'
```

#### Adding CA certs for the BASH aliases

Prior to using the aliases above for regular purposes you need to ensure that
the CA chains are properly imported into the NSS databases in the disparate
`alias` directories listed above.

Don't worry, you only need to do this **once per CA** and it is good to know
what commands are being run for future reference in case you need to add
additional certificates in the future!

The following uses `site-pki` as an example, but you need to repeat the steps
for all three aliased CAs.

```bash
# You'll want to do this in a temp directory, we'll use one in the $HOME/.dogtag space
[root@ca ~]# cd $HOME/.dogtag
[root@ca ~]# mkdir crt_tmp
[root@ca ~]# cd crt_tmp

# Obtain the PKCS12 certificate chain from the server
# This is good to host somewhere public to provide to your clients!

[root@ca crt_tmp]# pki-server ca-cert-chain-export -i simp-site-pki \
--pkcs12-file simp-site-pki-ca-chain.p12 \
--pkcs12-password-file $HOME/.dogtag/simp-site-pki/ca/password.conf

# Generate a PEM file containing all of the CA certificate chain from the PKCS12 file
# This is also good to provide to your clients

[root@ca crt_tmp]# openssl pkcs12 -in simp-site-pki-ca-chain.p12 \
-passin file:$HOME/.dogtag/simp-site-pki/ca/password.conf \
-out simp-site-pki-ca-chain.pem

# Split the PEM file out into separate PEM files for each CA
# This is done to get them into individual PKCS12 files for import into your NSS database
#
# You may also want to provide these to your clients for download but the
# single file or PKCS12 version is generally preferred

[root@ca crt_tmp]# mkdir ca_certs
[root@ca crt_tmp]# awk '/friendlyName:/{$1="";sub($1 OFS, "");n=$0} \
/^-----BEGIN.*CERTIFICATE/,/^-----END.*CERTIFICATE/{print >"ca_certs/"n".pem"}' \
< simp-site-pki-ca-chain.pem

# Finally, import the CA certificates into the associated trust chain NSS
# database

[root@ca crt_tmp]# cd ca_certs
[root@ca ca_certs]# for x in *.pem; do
  site-pki-base client-cert-import "`basename "$x" .pem`" --ca-cert "$x"
done
```

---

**IMPORTANT: IF YOU SKIPPED THIS SECTION, GO BACK AND READ IT!!!**

---

### Certificate Operations

#### Certmonger SCEP

##### Server Setup

You will first need to edit the `flatfile.txt` file in the appropriate CA.

For the `site-pki` CA, this would be in
`/var/lib/pki/simp-site-pki/ca/conf/flatfile.txt`.

The file is organized as a set of paired values, one for the **IP address**
(not hostname) of the client that will be enrolling and the other a unique, one
time use, password that will be used by the client during enrollment.

**Example**

    UID:1.2.3.4
    PWD:my_one_time_password

---

NOTE: You do **NOT** need to restart anything after editing the file!

---

##### Client Setup

1. Ensure that the `certmonger` package is installed and that the `certmonger`
   process is running and enabled.

   ```bash
   [root@ca ~]# yum -y install certmonger
   [root@ca ~]# systemctl start certmonger
   [root@ca ~]# systemctl enable certmonger
   ```

2. Obtain the public certificate for the CA that you will be connecting to. In
   this case, we'll assume that you've saved it to a file named
   `/etc/pki/site-pki-ca.pem` with SELinux context `cert_t`.

3. Obtain the full public certificate chain for the CA that you will be
   connecting to. In this case, we'll assume that you've saved it to a file
   named `/etc/pki/site-pki-ca-chain.pem` with SELinux context `cert_t`.

4. Add the CA to `certmonger`:

   ```bash
   [root@ca ~]# getcert add-scep-ca -c SIMP_Site \
     -u https://ca.your.domain:8443/ca/cgi-bin/pkiclient.exe \
     -R /etc/pki/site-pki-ca.pem
   ```

5. Ensure that your default `nssdb` space exists

   ```bash
   [root@ca ~]#
     if [ ! -d $HOME/.netscape ]; then
       certutil -N
     fi
   ```

6. Request a certificate using `certmonger`:

   ```bash
   [root@ca ~]# getcert request -c SIMP_Site -k /etc/pki/host_cert.pem \
     -f /etc/pki/host_cert.pub \
     -I Host_Cert_Nickname \
     -r -w -L <password from server setup step>
   ```

   **NOTE:** The target for the public and private keys **must** have context
   `cert_t` for `certmonger` to be able to write the keys appropriately.

---

**IMPORTANT:** Presently this will **NOT** work properly due to a bug in
`certmonger` and an associated bug in `dogtag` which, combined, result in the
inability to negotiate a proper cipher set for SCEP communication.

  * https://pagure.io/certmonger/issue/89
  * https://pagure.io/dogtagpki/issue/627

---

#### CMC Manual Enrollment

An alternate method for certificate enrollment,
[CMC](https://tools.ietf.org/html/rfc5273) may be used if you need to generate
certificates for a set of hosts or users and distribute them via the `simp-pki`
puppet module or some other means.

At this time, single use credentials have not been implemented so you should
not add this capability to all hosts.

All of the following steps should be done from a host that has access to one of
the privileged PKI user certificates (in general this is only your CA).

1. Create a certificate request for your host:

   * If you don't have a `~/.netscape` directory, you'll need to run `certutil
     -N` first!

    ```bash
    [root@ca ~]# mkdir -f CMC && cd CMC
    [root@ca CMC]# certutil -R -s "cn=`hostname -f`,ou=Hosts,dc=your,dc=domain" \
      -k rsa \
      -g 4096 \
      -Z SHA384 \
      -o hostcert.req
    ```

2. Create a `cmc-request.cfg` file with the following content:

   ```
   # NSS database directory.
   dbdir=/root/.dogtag/simp-site-pki/ca/alias

   # NSS database password.
   password=<password from /root/.dogtag/simp-site-pki/ca/password.conf>

   # Token name (default is internal).
   tokenname=internal

   # Nickname for CA agent certificate.
   nickname=caadmin

   # Request format: pkcs10 or crmf.
   format=pkcs10

   # Total number of PKCS10/CRMF requests.
   numRequests=1

   # Path to the PKCS10/CRMF request.
   # The content must be in Base-64 encoded format.
   # Multiple files are supported. They must be separated by space.
   input=/root/CMC/hostcert.req

   # Path for the CMC request.
   output=/root/CMC/sslserver-cmc-request.bin
   ```

3. Generate the `CMCRequest` *bin* file

   ```bash
   [root@ca CMC]# CMCRequest cmc-request.cfg
   ```

4. Create a `cmc-submit.cfg` file with the following content

   ```
   # PKI server host name.
   host=ca.<your.domain>

   # PKI server port number.
   port=8443

   # Use secure connection.
   secure=true

   # Use client authentication.
   clientmode=true

   # NSS database directory.
   dbdir=/root/.dogtag/simp-site-pki/ca/alias

   # NSS database password.
   password=<password from /root/.dogtag/simp-site-pki/ca/password.conf>

   # Token name (default: internal).
   tokenname=internal

   # Nickname of CA agent certificate.
   nickname=caadmin

   # CMC servlet path
   servlet=/ca/ee/ca/profileSubmitCMCFull?profileId=caCMCserverCert

   # Path for the CMC request.
   input=/root/CMC/sslserver-cmc-request.bin

   # Path for the CMC response.
   output=/root/CMC/sslserver-cmc-response.bin
   ```

5. Submit the CMC Request

   ```bash
   [root@ca CMC]# HttpClient cmc-submit.cfg
   ```

6. Unpack the signed certificate (you only need the CA cert in your `nssdb` for this)

   ```bash
   [root@ca CMC]# CMCResponse -d ~/.dogtag/simp-puppet-pki/ca/alias \
     -i sslserver-cmc-response.bin > signed_host_cert.pub
   ```

#### Listing Certificates

You can list the certificates for the `site` CA using the following command:

```bash
[root@ca ~]# site-pki cert-find
```

#### Certificate Revocation

You can revoke certificates from the `site` CA using the following command:

```bash
[root@ca ~]# site-pki cert-revoke <CERT ID>
```

---

**IMPORTANT:** Take care not to revoke any certificate below ID `0x9` since
those are internal subsystem certificates and may cause issues.

---

#### OCSP Validation

There is an OCSP endpoint attached to all CA systems automatically. To validate
that OCSP is working properly for the `site` CA, you can use the following
command:

```bash
[root@ca ~]# OCSPClient -d ~/.dogtag/simp-site-pki/ca/alias -h `hostname -f` \
  -p 8080 -t /ca/ocsp --serial 1 -vv -c caadmin
```

If that works, then you can try an external query by pulling the OCSP endpoint
out of a generated certificate as follows:

```bash
[root@ca ~]# openssl ocsp -issuer site-pki-ca-chain.pem -cert to_verify.pem \
  -text -url `openssl x509 -noout -ocsp_uri -in to_verify.pem`
```

### Directory Operations

The administrative DN for 389ds consists of the value in
`simp_pki_service::pki_security_domain` appended with `Directory Manager`.

By default, to access the 389ds configuration, you would use the following:

```bash
[root@ca ~]# ldapsearch -H ldap://localhost:389 -y $HOME/.dogtag/generated_configs/ds_pw.txt \
  -D "cn=SIMP Directory Manager" -s base -b "cn=config"
```

## Development

Please read our [Contribution Guide](http://simp.readthedocs.io/en/master/contributors_guide/index.html)
and visit our [Developer Wiki](https://simp-project.atlassian.net/wiki/display/SD/SIMP+Development+Home)

If you find any issues, they can be submitted to our
[JIRA](https://simp-project.atlassian.net).

[System Integrity Management Platform](https://simp-project.com)

