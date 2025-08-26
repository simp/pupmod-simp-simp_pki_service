# Validate that the passed Hash of CAs meets the following requirements:
#
# * There is at least one Root CA
# * Each Sub CA has defined a parent CA
# * Each Sub CA is bound to a Root CA (nested Sub CAs are not supported)
#
# The CA hashes are a one-to-one mapping to the parameters in
# ``simp_pki_service::ca``.
#
# This does **not** check that all options for each CA are valid, that is left
# to the defined types to which the hash components are passed.
#
# **Compilation will be terminated if validation fails**
#
Puppet::Functions.create_function(:'simp_pki_service::validate_ca_hash') do
  # @param ca_hash The CA Hash to process
  #
  # @raise RuntimeError if validation fails
  #
  # @return [None]
  #
  # @example Missing Root CA Failure
  #
  #   $ca_hash = {
  #     'sub_ca' => {
  #       'root_ca'   => false,
  #       'parent_ca' => 'unknown-ca'
  #     }
  #   }
  #   simp_pki_service::validate_ca_hash($ca_hash)
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
  #   simp_pki_service::validate_ca_hash($ca_hash)
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
  #   simp_pki_service::validate_ca_hash($ca_hash)
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
  #   simp_pki_service::validate_ca_hash($ca_hash)
  #
  dispatch :validate_ca_hash do
    required_param 'Hash[String[1], Hash]', :ca_hash
  end

  def validate_ca_hash(ca_hash)
    root_cas = ca_hash.select { |_k, v| v['root_ca'] }.keys
    sub_cas = ca_hash.keys - root_cas

    if root_cas.empty?
      raise('simp_pki_service::validate_ca_hash(): No Root CAs found in CA configuration Hash')
    end

    invalid_parent_cas = []
    sub_cas.each do |ca|
      parent_ca = ca_hash[ca]['parent_ca']

      unless parent_ca && root_cas.include?(parent_ca)
        invalid_parent_cas << ca
      end
    end

    return if invalid_parent_cas.empty?
    raise("simp_pki_service::validate_ca_hash(): '#{invalid_parent_cas.join(', ')}' do not have valid parent CAs")
  end
end
