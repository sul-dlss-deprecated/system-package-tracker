require 'rails_helper'

RSpec.describe Import::Gems, type: :model do

  describe '#update_source' do
    it 'create git repo' do
      stub_const('Import::Gems::REPORTS_DIR', 'spec/data/tmp/')
      Import::Gems.new.update_source()
      testfile = 'spec/data/tmp/ruby-advisory-db/README.md'
      expect(File.exist?(testfile)).to eq(true)
    end
  end

  # Test loading the ruby advisories.
  describe '#ruby_advisories' do
    it 'load known ruby advisories and check state' do
      stub_const('Import::Gems::REPORTS_DIR', 'spec/data/ruby-adv-test')
      stub_const('Import::Gems::RUBY_ADV_DIR', '/')
      Import::Gems.new.ruby_advisories

      # There are six advisories, but one is for a package we don't install
      # and so it will be skipped.
      advisories = Advisory.where(os_family: 'gem').order('name')
      expect(advisories.size).to eq(14)

      # activerecord should have four and one advisories, depending on version.
      packages = Package.where(name: 'activerecord').order('version')
      expect(packages.size).to eq(2)
      expect(packages.first.advisories.size).to eq(4)
      expect(packages.second.advisories.size).to eq(1)

      # rest-client should have two advisories.
      packages = Package.where(name: 'rest-client').order('version')
      expect(packages.size).to eq(1)
      expect(packages.first.advisories.size).to eq(2)

    end
  end
end
