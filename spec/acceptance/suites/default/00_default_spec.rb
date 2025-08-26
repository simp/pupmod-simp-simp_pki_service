require 'spec_helper_acceptance'

test_name 'Set up simp_pki_service'

describe 'Set up simp_pki_service' do
  ca_metadata = {
    'simp-pki-root' => {
      http_port: 4508,
      https_port: 4509,
      num_initial_certs: 10
    },
    'simp-puppet-pki' => {
      http_port: 5508,
      https_port: 5509,
      num_initial_certs: 7
    },
    'simp-site-pki' => {
      http_port: 8080,
      https_port: 8443,
      num_initial_certs: 7
    }
  }

  let(:manifest) do
    <<-EOS
      include '::simp_pki_service'
    EOS
  end

  # This is needed to lower the SCEP ciphers down to the defaults used by sscep
  # and certmonger
  # - The dogtag configuration files impacted by the hieradata below are as follows:
  #   - /etc/pki/simp-pki-root/ca/CS.cfg
  #   - /etc/pki/simp-puppet-pki/ca/CS.cfg
  #   - /etc/pki/simp-site-pki/ca/CS.cfg
  #   NOTE:  The default config delivered with dogtag can be found at
  #          /usr/share/pki/ca/conf/CS.cfg
  # - simp-site-pki ca.scep.encryptionAlgorithm and ca.scep.hashAlgorithm
  #   are set to DES and MD5, respectively, to test integration with
  #   certmonger < 0.79.6.   Per https://pagure.io/certmonger/issue/89,
  #   for certmonger < 0.79.6, when negotiating encryption and hashes
  #   via SCEP, certmonger falls back to its defaults of MD5 and DES,
  #   because dogtag doesn't support the GetCACaps command.
  #
  # FIXME:
  # - Figure out why sscep enrollment with an SHA384-encrypted request
  #   works in 20_puppet_swap_spec.rb, even though that encryption
  #   algorithm is **NOT** in ca.scep.allowedHashAlgorithms
  let(:hieradata) do
    <<-EOS
      simp_pki_service::custom_cas:
        'simp-puppet-pki':
          'ca_config':
            'ca.scep.allowedEncryptionAlgorithms': 'DES,DES3'
            'ca.scep.encryptionAlgorithm': 'DES'
            'ca.scep.allowedHashAlgorithms': 'MD5,SHA1,SHA256,SHA512'
            'ca.scep.hashAlgorithm': 'MD5'
        'simp-site-pki':
          'ca_config':
            'ca.scep.allowedEncryptionAlgorithms': 'DES,DES3'
            'ca.scep.encryptionAlgorithm': 'DES'
            'ca.scep.allowedHashAlgorithms': 'MD5,SHA1,SHA256,SHA512'
            'ca.scep.hashAlgorithm': 'MD5'
    EOS
  end

  hosts.each do |host|
    context "on #{host}" do
      it 'has a proper FQDN' do
        on(host, "hostname #{fact_on(host, 'fqdn')}")
        on(host, 'hostname -f > /etc/hostname')
      end
    end
  end

  hosts_with_role(hosts, 'ca').each do |host|
    context "on the CA server #{host}" do
      let(:nss_import_script) { File.join(File.dirname(__FILE__), 'files', 'nss_import.sh') }
      let(:import_script) { '/root/nss_import.sh' }

      # Using puppet_apply as a helper
      it 'works with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'installs NSS import script' do
        scp_to(host, nss_import_script, import_script)
        on(host, "chmod +x #{import_script}")
      end

      ca_metadata.each do |ca, info|
        context "for CA #{ca}" do
          it "imports #{ca} CA chains into the #{ca} NSS database" do
            on(host, "#{import_script} #{ca}")
          end

          it 'has appropriate initial certificates' do
            cert_list = get_cert_list(host, ca, info[:https_port])
            expect(cert_list).to match(%r{Number of entries returned #{info[:num_initial_certs]}*})
          end

          it 'responds to OCSP queries' do
            result = on(host, "OCSPClient -d ~/.dogtag/#{ca}/ca/alias -h $HOSTNAME -p #{info[:http_port]} -t /ca/ocsp --serial 1 -c caadmin").output.strip

            expect(result).to match(%r{CertID\.serialNumber=1})
          end

          it 'has a CRL' do
            host.mkdir_p(ca)
            on(host, %(curl -sk "https://$HOSTNAME:#{info[:https_port]}/ca/ee/ca/getCRL?op=getCRL&crlIssuingPoint=MasterCRL" | openssl crl -inform DER -outform PEM > #{ca}/crl))
          end
        end
      end
    end
  end
end
