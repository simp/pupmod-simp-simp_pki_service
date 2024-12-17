require 'spec_helper_acceptance'

test_name 'Swap Puppet PKI'

describe 'simp_pki_service' do
  ca_metadata = {
    'simp-puppet-pki' => {
      http_port: 5508,
      https_port: 5509
    }
  }

  let(:manifest) do
    <<-EOS
      include '::simp_pki_service'
    EOS
  end

  let(:working_dir) { '/root/pki_puppet_cert_dir' }
  let(:ca_host) { hosts_with_role(hosts, 'ca').first }
  let(:ca) { fact_on(ca_host, 'fqdn') }

  hosts_with_role(hosts, 'ca').each do |host|
    context "on the CA server #{host}" do
      it 'sets one time passwords for simp-puppet-pki SCEP requests from all clients' do
        create_scep_otps(hosts, host, 'simp-puppet-pki')
      end
    end
  end

  hosts_with_role(hosts, 'server').each do |host|
    context "on Puppet server #{host}" do
      it 'has the puppetserver installed' do
        install_package(host, 'puppetserver')
      end

      it 'disables the puppetserver CA' do
        create_remote_file(
          host,
          '/etc/puppetlabs/puppetserver/services.d/ca.cfg',
          'puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service',
        )
      end
    end
  end

  hosts.each do |host|
    context "on #{host}" do
      let(:fqdn) { fact_on(host, 'fqdn') }

      it 'has the latest puppet agent' do
        on(host, 'puppet resource package puppet-agent ensure=latest')
      end

      it 'has sscep installed' do
        host.install_package('sscep')
      end

      it 'has a working dir' do
        host.mkdir_p(working_dir)
      end

      it 'generates a host private key' do
        on(host, "cd #{working_dir} && openssl genrsa -out #{fqdn}.key 4096")
      end

      it 'generates a host CSR' do
        subject_alt_name = if host[:roles].include?('server')
                             # Set up the cert the same way that Puppet usually does
                             "subjectAltName = critical,DNS:#{fqdn},DNS:puppet.int.localdomain,DNS:puppet"
                           else
                             "subjectAltName = critical,DNS:#{fqdn}"
                           end

        create_remote_file(
          host,
          "#{working_dir}/request.cfg",
          <<-EOM,
[ req ]
prompt = no
distinguished_name = req_distinguished_name
attributes = req_attributes
req_extensions = v3_req

[ req_attributes ]
challengePassword=#{fqdn}

[ req_distinguished_name ]
CN = #{fqdn}

[ v3_req ]
basicConstraints = CA:FALSE
nsCertType = server, client, email, objsign
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
#{subject_alt_name}
          EOM
        )

        on(host, "cd #{working_dir} && openssl req -new -sha384 -key #{fqdn}.key -out #{fqdn}.csr -config request.cfg")
      end

      it 'gets the simp-puppet-pki CA certificate' do
        on(host, %(sscep getca -u http://#{ca}:#{ca_metadata['simp-puppet-pki'][:http_port]}/ca/cgi-bin/pkiclient.exe -c #{working_dir}/dogtag-ca.crt -F sha1))
      end

      it 'gets the CA certificate chain' do
        # Puppet expects the entire CA cert chain to be a concatenated set of
        # PEM-formatted certificates.
        raw_cert_chain = on(host, %(openssl s_client -host #{ca} -port #{ca_metadata['simp-puppet-pki'][:https_port]} -prexit -showcerts 2>/dev/null < /dev/null )).stdout

        certs = []
        cert_lines = nil
        cert_found = false
        raw_cert_chain.split("\n").each do |line|
          if line.include?('CERTIFICATE')
            if line.include?('BEGIN')
              cert_found = true
              cert_lines = []
            elsif line.include?('END')
              cert_lines << line
              certs << cert_lines.join("\n")
              cert_found = false
            end
          end
          cert_lines << line if cert_found
        end
        certs.uniq!
        create_remote_file(host,
          "#{working_dir}/dogtag-ca-chain.pem",
          "#{certs.join("\n")}\n")
      end

      it 'gets the CA CRL' do
        on(host,
%(curl -sk "https://#{ca}:#{ca_metadata['simp-puppet-pki'][:https_port]}/ca/ee/ca/getCRL?op=getCRL&crlIssuingPoint=MasterCRL" | openssl crl -inform DER -outform PEM > #{working_dir}/dogtag-ca-crl.pem))
      end

      it 'obtains a certificate from the CA' do
        on(host,
%(cd #{working_dir} && sscep enroll -u http://#{ca}:#{ca_metadata['simp-puppet-pki'][:http_port]}/ca/cgi-bin/pkiclient.exe -c dogtag-ca.crt -k #{fqdn}.key -r #{fqdn}.csr -l #{fqdn}.pem -S sha1 -v -d))

        cert_list = get_cert_list(ca_host, 'simp-puppet-pki', ca_metadata['simp-puppet-pki'][:https_port])
        expect(cert_list).to match(%r{Subject DN: CN=#{fqdn}})
      end

      if host[:roles].include?('server')
        it 'ensures that the puppetserver is stopped' do
          on(host, 'puppet resource service puppetserver ensure=stopped')
        end
      end

      it 'replaces the puppet certificates' do
        install_cmd = 'install -D -m 600 -o `puppet config print user` -g `puppet config print group`'

        on(host, %(cd #{working_dir} && #{install_cmd} #{fqdn}.pem `puppet config print hostcert --section agent`))
        on(host, %(cd #{working_dir} && #{install_cmd} #{fqdn}.key `puppet config print hostprivkey --section agent`))
        on(host, %(cd #{working_dir} && #{install_cmd} dogtag-ca-chain.pem `puppet config print localcacert --section agent`))
        on(host, %(cd #{working_dir} && #{install_cmd}  dogtag-ca-crl.pem `puppet config print hostcrl --section agent`))
        on(host, %(cd #{working_dir} && #{install_cmd} dogtag-ca-crl.pem `puppet config print ssldir --section master`/ca/ca_crl.pem))
      end

      it 'sets the puppet certname' do
        on(host, "puppet config set certname #{fqdn}")
      end

      # This is needed due to a bug in puppet and is documented at
      # https://puppet.com/docs/puppet/5.3/config_ssl_external_ca.html
      # UPDATE:  Not fixed as of Puppet 6.7.2
      it 'sets CRL checking to false' do
        on(host, 'puppet config set certificate_revocation false')
      end

      if host[:roles].include?('server')
        it 'ensures that the puppetserver is stopped' do
          on(host, 'puppet resource service puppetserver ensure=stopped')
        end
      end
    end
  end

  context 'when enabling puppet with DogTag PKI certs' do
    hosts_with_role(hosts, 'server').each do |host|
      it 'ensures that the puppetserver is running' do
        on(host, 'puppet resource service puppetserver ensure=running')
      end
    end

    hosts.each do |host|
      context "on #{host}" do
        it 'connects to the puppet server' do
          on(host, %(puppet config set server #{ca}))
          on(host, %(puppet agent -t))
        end
      end
    end
  end
end
