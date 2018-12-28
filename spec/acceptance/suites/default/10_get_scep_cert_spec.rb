require 'spec_helper_acceptance'

test_name 'obtain SCEP certificates using sscep'

describe 'simp_pki_service' do
  ca_metadata = {
    'simp-puppet-pki' => {
      'http_port'  => 5508,
      'https_port' => 5509
    },
    'simp-site-pki' => {
      'http_port'  => 8080,
      'https_port' => 8443
    }
  }

  hosts_with_role(hosts, 'ca').each do |host|
    context host do
      ca_metadata.keys.each do |ca|
        context "CA #{ca}" do
          it 'should have a artifact collection directory' do
            host.mkdir_p(ca)
          end

          it 'should have a password set for SCEP requests for the host' do
            on(host, %{echo -e "UID:`hostname -i`\\nPWD:password" > /var/lib/pki/#{ca}/ca/conf/flatfile.txt})
          end

          it 'should have sscep installed' do
            host.install_package('sscep')
          end

          it 'should get the CA certificate' do
            on(host, %{sscep getca -u http://$HOSTNAME:#{ca_metadata[ca]['http_port']}/ca/cgi-bin/pkiclient.exe -c #{ca}/ca.crt})
          end

          it 'should generate a certificate request' do
            on(host, %{cd #{ca} && mkrequest -ip `hostname -i` password})
          end

          it 'should enroll the certificate' do
            on(host, %{cd #{ca} && sscep enroll -u http://$HOSTNAME:#{ca_metadata[ca]['http_port']}/ca/cgi-bin/pkiclient.exe -c ca.crt -k local.key -r local.csr -l cert.crt})
          end
        end
      end
    end
  end
end
