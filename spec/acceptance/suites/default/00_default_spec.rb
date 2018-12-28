require 'spec_helper_acceptance'

test_name 'simp_pki_service'

describe 'simp_pki_service' do
  ca_metadata = {
    'simp-pki-root' => {
      'http_port'  => 4508,
      'https_port' => 4509
    },
    'simp-puppet-pki' => {
      'http_port'  => 5508,
      'https_port' => 5509
    },
    'simp-site-pki' => {
      'http_port'  => 8080,
      'https_port' => 8443
    }
  }

  let(:manifest) {
    <<-EOS
      include '::simp_pki_service'
    EOS
  }

  # This is needed to lower the SCEP ciphers down to the defaults used by sscep
  # and certmonger by default
  let(:hieradata) {
    <<-EOS
      simp_pki_service::custom_cas:
        'simp-puppet-pki':
          'ca_config':
            'ca.scep.allowedEncryptionAlgorithms': 'DES,DES3'
            'ca.scep.EncryptionAlgorithm': 'DES'
            'ca.scep.allowedHashAlgorithms': 'MD5,SHA1,SHA256,SHA512'
            'ca.scep.HashAlgorithm': 'MD5'
        'simp-site-pki':
          'ca_config':
            'ca.scep.allowedEncryptionAlgorithms': 'DES,DES3'
            'ca.scep.EncryptionAlgorithm': 'DES'
            'ca.scep.allowedHashAlgorithms': 'MD5,SHA1,SHA256,SHA512'
    EOS
  }

  hosts.each do |host|
    context "on #{host}" do
      it 'should have a proper FQDN' do
        on(host, "hostname #{fact_on(host, 'fqdn')}")
        on(host, 'hostname -f > /etc/hostname')
      end
    end
  end

  hosts_with_role(hosts, 'ca').each do |host|
    context "on the CA" do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_changes => true)
      end

      ca_metadata.keys.each do |ca|
        context "CA #{ca}" do
          it 'should have a artifact collection directory' do
            host.mkdir_p(ca)
          end

          it 'should respond to OCSP queries' do
            result = on(host, "OCSPClient -d ~/.dogtag/#{ca}/ca/alias -h $HOSTNAME -p #{ca_metadata[ca]['http_port']} -t /ca/ocsp --serial 1 -c caadmin").output.strip

            expect(result).to match(/CertID\.serialNumber=1/)
          end

          it 'should have a CRL' do
            on(host, %{curl -sk "https://$HOSTNAME:#{ca_metadata[ca]['https_port']}/ca/ee/ca/getCRL?op=getCRL&crlIssuingPoint=MasterCRL" | openssl crl -inform DER -outform PEM > #{ca}/crl})
          end
        end
      end
    end
  end
end
