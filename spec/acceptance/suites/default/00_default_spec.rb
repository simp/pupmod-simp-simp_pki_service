require 'spec_helper_acceptance'

test_name 'simp_pki_service'

describe 'simp_pki_service' do
  let(:manifest) {
    <<-EOS
      include '::simp_pki_service'
    EOS
  }

  hosts.each do |host|
    context "on a host" do
      it 'should have a proper FQDN' do
        on(host, "hostname #{fact_on(host, 'fqdn')}")
        on(host, 'hostname -f > /etc/hostname')
      end

      # Using puppet_apply as a helper
      it 'should work with no errors' do
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_changes => true)
      end
    end
  end
end
