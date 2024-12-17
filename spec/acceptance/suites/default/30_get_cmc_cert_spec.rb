require 'spec_helper_acceptance'

test_name 'Client enroll via CMC on CA server'

describe 'Client enroll via CMC on CA server' do
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

  hosts_with_role(hosts, 'ca').each do |ca_host|
    let(:domain) { fact_on(ca_host, 'domain') }

    context "on CA server #{ca_host}" do
      it 'ensures the default NSS database exists' do
        results = on(ca_host, 'ls /root/.netscape', accept_all_exit_codes: true)
        if results.exit_code != 0
          on(ca_host, 'mkdir /root/.netscape')
          # Creating a NSS DB without a password is not recommended for a real
          # system, but OK for this test
          on(ca_host, 'certutil -N --empty-password')
        end
      end

      ca_metadata.each do |ca, info|
        context "for CA #{ca}" do
          let(:working_dir) { File.join('cmc', ca) }

          it 'has a artifact collection directory' do
            ca_host.mkdir_p(working_dir)
          end

          hosts.each do |client|
            context "for client '#{client}'" do
              let(:client_fqdn) { fact_on(client, 'fqdn') }
              let(:client_cn) { "#{client_fqdn} from cmc" }

              let(:client_cert_request_file)   { File.join(working_dir, "#{client}_cert.req") }
              let(:client_cmc_submit_cfg_file) { File.join(working_dir, "#{client}_cmc_submit.cfg") }
              let(:client_cmc_response_file)   { File.join(working_dir, "#{client}_cmc_response.bin") }

              it 'creates a certificate request' do
                # seed file needs to be at least 20 bytes in length, so
                # one 512-byte block will be more than enough
                seed_file = File.join(working_dir, 'seed')
                on(ca_host, "dd if=/dev/urandom of=#{seed_file} count=1")
                cmd = [
                  'certutil -R',
                  "-s \"cn=#{client_cn}\"",
                  '-k rsa',
                  '-g 4096',
                  '-Z SHA384',
                  "-z #{seed_file}",
                  '| openssl req -inform DER -outform PEM > ',
                  client_cert_request_file,
                ]
                on(ca_host, cmd.join(' '))
              end

              it 'prepares CMC files for the request' do
                cfg = {
                  ca: {
                    host: ca_host,
                    name: ca,
                    https_port: info[:https_port],
                    password: on(ca_host, "cat  /root/.dogtag/#{ca}/ca/password.conf").stdout
                  },
                  files: {
                    cert_request: client_cert_request_file,
                    cmc_request_cfg: client_cmc_submit_cfg_file.gsub('submit', 'request'),
                    cmc_request: client_cmc_response_file.gsub('response', 'request'),
                    cmc_submit_cfg: client_cmc_submit_cfg_file,
                    cmc_response: client_cmc_response_file
                  }
                }
                generate_cmc_request_files(cfg)
              end

              it 'submits the request using CMC' do
                on(ca_host, "HttpClient #{client_cmc_submit_cfg_file}")

                client_pkcs7_file = File.join(working_dir, "#{client}_cert_chain.p7b")
                cmd = [
                  'CMCResponse',
                  "-d /root/.dogtag/#{ca}/ca/alias",
                  "-i #{client_cmc_response_file}",
                  "-o #{client_pkcs7_file}",
                ]
                on(ca_host, cmd.join(' '))

                client_cert_file = File.join(working_dir, "#{client}_cert.pem")
                extract_cert_from_pkcs7(ca_host, client_pkcs7_file, client_cert_file, client_cn)
                verify_cert(ca_host, ca, info[:https_port], ca_host, client_cert_file, client_cn)
              end
            end
          end
        end
      end
    end
  end
end
