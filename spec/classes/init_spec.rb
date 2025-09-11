require 'spec_helper'

describe 'simp_pki_service' do
  on_supported_os.each_value do |facts|
    let(:facts) { facts }

    it { is_expected.to compile.with_all_deps }
  end
end
