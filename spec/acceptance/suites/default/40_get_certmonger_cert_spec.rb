require 'spec_helper_acceptance'

test_name 'Client enroll via certmonger'

describe 'Client enroll via certmonger'
ca_metadata = {
  'simp-puppet-pki' => {
    http_port: 5508,
    https_port: 5509
  },
  'simp-site-pki' => {
    http_port: 8080,
    https_port: 8443
  }
}

ca   = 'simp-site-pki'
info = ca_metadata['simp-site-pki']

hosts_with_role(hosts, 'ca').each do |ca_host|
  context "CA server #{ca_host}" do
    let(:ca_hostname) { fact_on(ca_host, 'fqdn') }

    context "on CA server #{ca_host} for CA #{ca}" do
      it "sets one time passwords for #{ca} SCEP requests from all clients" do
        create_scep_otps(hosts, ca_host, ca, 'one-time-password')
      end

      hosts.each do |client|
        context "on client #{client}" do
          let(:client_fqdn) { fact_on(client, 'fqdn') }

          it 'install,s start, and enable certmonger' do
            client.install_package('certmonger')
            on(client, 'puppet resource service certmonger ensure=running')
            on(client, 'puppet resource service certmonger enable=true')
          end

          it 'obtains CA certificates' do
            # Real distribution mechanism TBD.  Using insecure pull for test simplicity.
            cmd = [
              '/usr/libexec/certmonger/scep-submit',
              "-u http://#{ca_hostname}:#{info[:http_port]}/ca/cgi-bin/pkiclient.exe",
              '-C', # retrieve CA certificates
            ]
            certs = on(client, cmd.join(' ')).stdout.split("-----END CERTIFICATE-----\n")
            certs.map! { |cert| cert.strip + "\n-----END CERTIFICATE-----\n" }

            # 1st certificate is for simp-site-pki
            create_remote_file(client, "/etc/pki/#{ca}-ca.pem", certs[0])
            on(client, "ls -Z /etc/pki/#{ca}-ca.pem")

            # 2nd certificate is for simp-pki-root
            create_remote_file(client, '/etc/pki/simp-pki-root-ca.pem', certs[1])
            on(client, 'ls -Z /etc/pki/simp-pki-root-ca.pem')
          end

          it 'adds the CA to certmonger' do
            cmd = [
              'getcert add-scep-ca',
              '-c SIMP_Site',
              "-u https://#{ca_hostname}:#{info[:https_port]}/ca/cgi-bin/pkiclient.exe",
              '-R /etc/pki/simp-pki-root-ca.pem',
              "-I /etc/pki/#{ca}-ca.pem",
            ]

            on(client, cmd.join(' '))
          end

          it 'ensures the default NSS database exists' do
            results = on(client, 'ls /root/.netscape', accept_all_exit_codes: true)
            if results.exit_code != 0
              on(client, 'mkdir /root/.netscape')
              # Creating a NSS DB without a password is not recommended for a real
              # system, but OK for this test
              on(client, 'certutil -N --empty-password')
            end
          end

          it 'requests a certificate using certmonger' do
            cmd = [
              'getcert request',
              '-c SIMP_Site',
              "-k /etc/pki/#{client_fqdn}.pem",
              "-f /etc/pki/#{client_fqdn}.pub",
              "-I #{client_fqdn}",
              '-r -w -v',
              '-L one-time-password',
            ]

            on(client, cmd.join(' '))
            on(client, 'getcert list')

            on(client, "ls /etc/pki/#{client_fqdn}.pub")
            verify_cert(ca_host, ca, info[:https_port], client, "/etc/pki/#{client_fqdn}.pub", client_fqdn)
          end
        end
      end
    end
  end
end
