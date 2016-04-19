require 'rails_helper'

RSpec.describe Import::Servers, type: :model do
  describe "#servers" do
    it "loads server files correctly" do
      stub_const('Import::Servers::SERVER_FILES', 'spec/data/servers/*.yaml')
      described_class.new.servers

      servers = Server.where("hostname LIKE 'import%.stanford.edu'")
                      .order('hostname')
      expect(servers.size).to eq(2)

      # Installed and pending packages for each server have the right count.
      expect(servers.first.installed_packages.size).to eq(6)
      expect(servers.first.pending_packages.size).to eq(2)
      expect(servers.second.installed_packages.size).to eq(4)
      expect(servers.second.pending_packages.size).to eq(1)
    end
  end
end
