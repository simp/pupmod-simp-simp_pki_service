require 'spec_helper'

describe 'simp_pki_service::validate_ca_hash' do
  context 'with a valid hash' do
    let(:ca_hash) {{
      'pki-root' => {
        'root_ca' => true
      },
      'pki-sub'  => {
        'root_ca'   => false,
        'parent_ca' => 'pki-root'
      }
    }}

    it { is_expected.to run.with_params(ca_hash) }
  end

  context 'with a missing root CA' do
    let(:ca_hash) {{
      'pki-sub'  => {
        'root_ca'   => false,
        'parent_ca' => 'pki-root'
      }
    }}

    it do
      is_expected.to run.with_params(ca_hash).and_raise_error( /No Root CAs found/)
    end
  end

  context 'without a defined parent CA' do
    let(:ca_hash) {{
      'pki-root' => {
        'root_ca' => true
      },
      'pki-sub'  => {
        'root_ca'   => false
      }
    }}

    it do
      is_expected.to run.with_params(ca_hash).and_raise_error( /pki-sub.*do not have valid parent CAs/)
    end
  end

  context 'without an invalid defined parent CA' do
    let(:ca_hash) {{
      'pki-root' => {
        'root_ca' => true
      },
      'pki-sub'  => {
        'root_ca'   => false,
        'parent_ca' => 'unknown-ca'
      }
    }}

    it do
      is_expected.to run.with_params(ca_hash).and_raise_error( /pki-sub.*do not have valid parent CAs/)
    end
  end

end
