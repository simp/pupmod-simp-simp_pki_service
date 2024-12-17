module Acceptance::Helpers::PkiUtils
  # Creates SCEP one time passwords for a list of clients
  #
  # +client+:   Array of client Host objects
  # +ca_host+:  Host object for the CA
  # +ca+:       Name of the CA
  # +password+: One time password to use.  When omitted, defaults to the
  #   client's FQDN
  #
  def create_scep_otps(clients, ca_host, ca, password = nil)
    # NOTE: the flatfile.txt format requires a blank space between entries
    auth_file_content = [
      "UID:127.0.0.1\nPWD:#{password.nil? ? fact_on(ca_host, 'fqdn').strip : password}",
      clients.map do |h|
        "UID:#{h.ip}\nPWD:#{password.nil? ? fact_on(h, 'fqdn').strip : password}"
      end,
    ].flatten.join("\n\n")

    auth_file = "/var/lib/pki/#{ca}/ca/conf/flatfile.txt"
    create_remote_file(ca_host, auth_file, auth_file_content)
  end

  # Extracts the certificate for a specified subject from a PKCS #7
  # PEM-formatted file and writes it to a PEM-formatted output file.
  #
  # @fails if a certificat for the specified subject does not exist
  #        in the PKCS #7 input file
  #
  # +host+:          Host object for the server where the input file
  #                  resides
  # +pkcs7_file+:    PCKS #7 input file derived from a CMC response
  #                  file. It contains the CA cert chain for the cert
  #                  having the specified subject.
  # +cert_file+:     Output certificate file
  # +cert_subject+:  Certificate subject, excluding the 'cn=' or 'CN='
  def extract_cert_from_pkcs7(host, pkcs7_file, cert_file, cert_subject)
    # Extract certs in the cert chain from PCKS #7
    cert_chain_file = "#{pkcs7_file}.pem"
    on(host, "openssl pkcs7 -print_certs -in #{pkcs7_file} -out #{cert_chain_file}")
    cert_chains_raw = on(host, "cat #{cert_chain_file}").stdout

    cert_chains = []
    cert_lines = []
    cert_found = false
    cert_chains_raw.split("\n").each do |line|
      next if line.strip.empty?
      if line.match?(%r{^subject})
        cert_found = true
        cert_lines = []
      elsif line.include?('END CERTIFICATE')
        cert_found = false
        cert_lines << line
        cert_chains << cert_lines.join("\n")
      end
      cert_lines << line if cert_found
    end

    cert_content = nil
    cert_chains.each do |cert|
      unless cert.match?(%r{^subject.*CA Signing Certificate$})
        next unless cert.match?(%r{CN\s*=\s*#{cert_subject}})
        cert_content = cert.gsub(%r{^.*BEGIN }m, '-----BEGIN ')
      end
    end

    if cert_content
      create_remote_file(host, cert_file, cert_content)
    else
      # To aid debug, print out certs from the PKCS #7 file
      on(host, "openssl pkcs7 -print_certs -in #{pkcs7_file}")
      raise("Certificate for '#{cert_subject}' does not exist in #{pkcs7_file} on #{host}")
    end
  end

  # Generate a CMC request (bin) file and a corresponding CMC
  # config file, both of which are required to submit the
  # certificate request to the CA using CMC.
  #
  # +cfg+:  Hash of hashes with CA and file name info.  Primary keys
  #         are :ca and :files, respectively.
  #
  # The value of the :ca key is a Hash with the following keys
  # - :host :       Host object for the CA
  # - :name :       Name of the CA
  # - :https_port : HTTPS port to use to communicate with the CA
  # - :password :   NSS database password for the CA
  #
  # The value of the :files key is a Hash with the following keys:
  # - :cert_request :    Certificate request file
  # - :cmc_request_cfg : CMC request config file
  # - :cmc_request :     CMC request 'bin' file
  # - :cmc_submit_cfg :  CMC submit config file
  # - :cmc_response :    CMC response 'bin' file
  #
  def generate_cmc_request_files(cfg)
    # create a CMC config file that specifies how to generate
    # the CMC request file from the certificate request file
    generate_cmc_request_cfg(cfg)

    # using the CMC config file, generate the CMC request file
    on(cfg[:ca][:host], "CMCRequest #{cfg[:files][:cmc_request_cfg]}")

    # create a CMC submit config file that specifies how to
    # generate the CMC response from the CMC request
    generate_cmc_submit_cfg(cfg)
  end

  def generate_cmc_request_cfg(cfg)
    cfg_content = <<-EOM
# NSS database directory.
dbdir=/root/.dogtag/#{cfg[:ca][:name]}/ca/alias

# NSS database password.
password=#{cfg[:ca][:password]}

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
input=#{cfg[:files][:cert_request]}

# Path for the CMC request.
output=#{cfg[:files][:cmc_request]}
        EOM

    create_remote_file(cfg[:ca][:host], cfg[:files][:cmc_request_cfg], cfg_content)
  end

  def generate_cmc_submit_cfg(cfg)
    ca_fqdn = fact_on(cfg[:ca][:host], 'fqdn')
    cfg_content = <<-EOM
# PKI server host name.
host=#{ca_fqdn}

# PKI server port number.
port=#{cfg[:ca][:https_port]}

# Use secure connection.
secure=true

# Use client authentication.
clientmode=true

# NSS database directory.
dbdir=/root/.dogtag/#{cfg[:ca][:name]}/ca/alias

# NSS database password.
password=#{cfg[:ca][:password]}

# Token name (default: internal).
tokenname=internal

# Nickname of CA agent certificate.
nickname=caadmin

# CMC servlet path
servlet=/ca/ee/ca/profileSubmitCMCFull?profileId=caCMCserverCert

# Path for the CMC request.
input=#{cfg[:files][:cmc_request]}

# Path for the CMC response.
output=#{cfg[:files][:cmc_response]}
        EOM

    create_remote_file(cfg[:ca][:host], cfg[:files][:cmc_submit_cfg], cfg_content)
  end

  # @returns Certificate list for the specified CA
  #
  # Executes the `pki cert-find` command on ca_host for the
  # ca at https_port
  #
  # +ca_host+:       Host object for the CA
  # +ca+:            Name of the CA
  # +ca_https_port+: HTTPS port to use to communicate with the CA
  #
  # @fails if the CA certificate chain has *NOT* been imported into
  #        NSS database for that CA
  #
  def get_cert_list(ca_host, ca, ca_https_port)
    cert_list_cmd = [
      'pki',
      "-d $HOME/.dogtag/#{ca}/ca/alias",
      "-C $HOME/.dogtag/#{ca}/ca/password.conf",
      '-n "caadmin"',
      '-P https',
      "-p #{ca_https_port} cert-find",
    ]
    result = on(ca_host, cert_list_cmd.join(' '))
    result.stdout
  end

  # Verifies the following about a certificate file
  # - Valid x509 PEM format
  # - The issuer matches the CA
  # - The subject matches the expected
  # - The serial number is found in the CA's cert list
  #
  # +ca_host+:       Host object for the CA
  # +ca+:            Name of the CA
  # +ca_https_port+: HTTPS port to use to communicate with the CA
  # +cert_host+:     Host object on which the certificate file resides
  # +cert_file+:     Path to the certificate file
  # +cert_subject+:  Certificate subject, excluding the 'cn=' or 'CN='
  #
  def verify_cert(ca_host, ca, ca_https_port, cert_host, cert_file, cert_subject)
    cert_text = on(cert_host, "openssl x509 -in #{cert_file} -text -noout").stdout
    expect(cert_text).to match(%r{Issuer: O\s*=\s*SIMP, OU\s*=\s*#{Regexp.escape(ca)}, CN\s*=\s*CA Signing Certificate})
    expect(cert_text).to match(%r{Subject: CN\s*=\s*#{Regexp.escape(cert_subject)}})

    match_data = cert_text.match(%r{Serial Number: [0-9]+ \((0[xX]{1}[0-9a-fA-F]+)\)})
    expect(match_data).not_to be_nil
    serial_num = match_data[1]
    expect(serial_num).not_to be_nil

    cert_list = get_cert_list(ca_host, ca, ca_https_port)
    expect(cert_list).to match(%r{Serial Number: #{serial_num}})
  end
end
