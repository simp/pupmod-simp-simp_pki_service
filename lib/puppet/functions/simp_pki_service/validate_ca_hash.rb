# Validate that the passed Hash of CAs meets the following requirements:
#
# * There is at least one Root CA
# * Each Sub CA has defined a parent CA
# * Each Sub CA Has a Root CA in the list
#
# This does **not** check that the options are valid, that is left to the
# defined types to which the hash components are passed.
#
Puppet::Functions.create_function(:'simp_pki_service::validate_ca_hash') do

  # @param ca_hash The CA Hash to process
  #
  # @example Missing Root CA Failure
  #
  #   $ca_hash = {
  #     'sub_ca' => {
  #       'root_ca'   => false,
  #       'parent_ca' => 'unknown-ca'
  #     }
  #   }
  #   validate_ca_hash($ca_hash)
  #
  # @example No Parent CA Defined Failure
  #
  #   $ca_hash = {
  #     'pki-root' => {
  #       'root_ca' => true
  #     },
  #     'pki-sub' => {
  #       'root_ca'   => false
  #     }
  #   }
  #   validate_ca_hash($ca_hash)
  #
  # @example Missing Parent Root CA Failure
  #
  #   $ca_hash = {
  #     'pki-root' => {
  #       'root_ca' => true
  #     },
  #     'pki-sub' => {
  #       'root_ca'   => false,
  #       'parent_ca' => 'missing-ca'
  #     }
  #   }
  #   validate_ca_hash($ca_hash)
  #
  # @example Valid Hash
  #
  #   $ca_hash = {
  #     'pki-root' => {
  #       'root_ca' => true
  #     },
  #     'pki-sub' => {
  #       'root_ca'   => false,
  #       'parent_ca' => 'pki-root'
  #     }
  #   }
  #   validate_ca_hash($ca_hash)
  #
  dispatch :validate_ca_hash do
    required_param 'Hash[String[1], Hash]', :ca_hash
  end

  def validate_ca_hash(ca_hash)
    root_cas = ca_hash.select{|k,v| v['root_ca']}.keys

    if root_cas.empty?
      fail('simp_pki_service::validate_ca_hash(): No Root CAs found in CA configuration Hash')
    end

    invalid_parent_cas = []
    (ca_hash.keys - root_cas).each do |ca|
      parent_ca = ca_hash[ca]['parent_ca']

      unless parent_ca && root_cas.include?(parent_ca)
        invalid_parent_cas << ca
      end
    end

    unless invalid_parent_cas.empty?
      fail("simp_pki_service::validate_ca_hash(): '#{invalid_parent_cas.join(', ')}' do not have valid parent CAs")
    end
  end
end
