require 'rails_helper'

RSpec.describe Import, type: :model do

  # Tests for loading server data.
  describe '#servers' do
    it "loads server files correctly" do
      stub_const('Import::SERVER_FILES', 'spec/data/servers/*.yaml')
      Import.new.servers

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

  # Tests for parsing a major release version from an RPM name.
  describe '#centos_package_major_release' do
    it "finds the right major release for an el* package" do
      rpm = 'xen-3.0.3-135.el5_8.2.i386.rpm'
      expect(Import.new.centos_package_major_release(rpm)).to eq(5)
    end
    it "finds the right major release for an centos* package" do
      rpm = 'up2date-4.4.5.6-2.centos4.i386.rpm'
      expect(Import.new.centos_package_major_release(rpm)).to eq(4)
    end
    it "finds the right major release for an rhel* package" do
      rpm = 'xloadimage-4.1-34.RHEL4.x86_64.rpm'
      expect(Import.new.centos_package_major_release(rpm)).to eq(4)
    end
    it "finds no major release for a package without" do
      rpm = 'nfs-utils-1.0.9-60.i386.rpm'
      expect(Import.new.centos_package_major_release(rpm)).to eq(0)
    end
  end

  # Tests for seeing if a package is in a list of major release versions.
  describe '#used_release?' do
    it "package is in default major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      expect(Import.new.used_release?(packages)).to be true
    end
    it "package is outside of default major releases" do
      packages = ['xen-3.0.3-135.el4_8.2.i386.rpm']
      expect(Import.new.used_release?(packages)).to be false
    end
    it "package is in specific major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      releases = [5, 6]
      expect(Import.new.used_release?(packages, releases)).to be true
    end
    it "package is outside of specific major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      releases = [6, 7]
      expect(Import.new.used_release?(packages, releases)).to be false
    end
  end

  # Get CentOS advisory XML contents.
  describe '#get_centos_advisories' do
    it 'fetch centos advisories' do
      xml_data = Import.new.get_centos_advisories()
      expect(xml_data).to match(/^<opt>/)
    end
  end

  # Actually load the CentOS advisories to make sure they work correctly.
  describe '#centos_advisories' do
    fixtures :packages

    it 'load known data and check state' do
      import = Import.new

      # Set up a known subset of the advisories XML.
      xml = '<opt><CESA-2012--0370 description="Not available" from="centos-announce@centos.org" issue_date="2012-03-07 23:16:09" multirelease="1" notes="Not available" product="CentOS Linux" references="https://rhn.redhat.com/errata/RHSA-2012-0370.html http://lists.centos.org/pipermail/centos-announce/2012-March/018479.html" release="1" severity="Important" solution="Not available" synopsis="Important CentOS xen security and bug fix update" topic="Not available" type="Security Advisory"><os_arch>i386</os_arch><os_arch>x86_64</os_arch><os_release>5</os_release><packages>xen-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-3.0.3-135.el5_8.2.src.rpm</packages><packages>xen-3.0.3-135.el5_8.2.x86_64.rpm</packages><packages>xen-devel-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-devel-3.0.3-135.el5_8.2.x86_64.rpm</packages><packages>xen-libs-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-libs-3.0.3-135.el5_8.2.x86_64.rpm</packages></CESA-2012--0370><meta><author>Steve Meier</author><license>Free for non-commercial use</license><disclaimer>This software is provided AS IS. There are no guarantees. It might kill your cat.</disclaimer><timestamp>Thu Feb 11 09:08:36 UTC 2016</timestamp></meta></opt>'
      allow(import).to receive(:get_centos_advisories).and_return(xml)

      import.centos_advisories

      # Make sure advisory exists and has only the one correct package.
      adv = Advisory.find_by(name: 'CESA-2012--0370')
      expect(adv.name).to eq('CESA-2012--0370')
      expect(adv.packages.size).to eq(1)
      expect(adv.packages.first.name).to eq('xen')
      expect(adv.packages.first.version).to eq('3.0.0-1.el5')
    end
  end

  # Test loading the ruby advisories.
  describe '#ruby_advisories' do
    it 'load known ruby advisories and check state' do
      stub_const('Import::ADV_DIRECTORY', 'spec/data/ruby-advisory-db/gems')
      Import.new.ruby_advisories

      # There are six advisories, but one is for a package we don't install
      # and so it will be skipped.
      advisories = Advisory.where(os_family: 'gem').order('name')
      expect(advisories.size).to eq(5)

      # activerecord should have two and no advisories, depending on version.
      packages = Package.where(name: 'activerecord').order('version')
      expect(packages.size).to eq(2)
      expect(packages.first.advisories.size).to eq(2)
      expect(packages.second.advisories.size).to eq(0)

      # rest-client should have two advisories.
      packages = Package.where(name: 'rest-client').order('version')
      expect(packages.size).to eq(1)
      expect(packages.first.advisories.size).to eq(2)

    end
  end

end
