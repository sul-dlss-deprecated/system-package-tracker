require 'rails_helper'

RSpec.describe Import::Yum, type: :model do

  # Tests for parsing a major release version from an RPM name.
  describe '#centos_package_major_release' do
    it "finds the right major release for an el* package" do
      rpm = 'xen-3.0.3-135.el5_8.2.i386.rpm'
      expect(Import::Yum.new.centos_package_major_release(rpm)).to eq(5)
    end
    it "finds the right major release for an centos* package" do
      rpm = 'up2date-4.4.5.6-2.centos4.i386.rpm'
      expect(Import::Yum.new.centos_package_major_release(rpm)).to eq(4)
    end
    it "finds the right major release for an rhel* package" do
      rpm = 'xloadimage-4.1-34.RHEL4.x86_64.rpm'
      expect(Import::Yum.new.centos_package_major_release(rpm)).to eq(4)
    end
    it "finds no major release for a package without" do
      rpm = 'nfs-utils-1.0.9-60.i386.rpm'
      expect(Import::Yum.new.centos_package_major_release(rpm)).to eq(0)
    end
  end

  # Tests for seeing if a package is in a list of major release versions.
  describe '#used_release?' do
    it "package is in default major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      expect(Import::Yum.new.used_release?(packages)).to be true
    end
    it "package is outside of default major releases" do
      packages = ['xen-3.0.3-135.el4_8.2.i386.rpm']
      expect(Import::Yum.new.used_release?(packages)).to be false
    end
    it "package is in specific major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      releases = [5, 6]
      expect(Import::Yum.new.used_release?(packages, releases)).to be true
    end
    it "package is outside of specific major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      releases = [6, 7]
      expect(Import::Yum.new.used_release?(packages, releases)).to be false
    end
  end

  # Get CentOS advisory XML contents.
  describe '#get_centos_advisories' do
    it 'fetch centos advisories' do
      stub_const('Import::Yum::PROXY_ADDR', '')
      xml_data = Import::Yum.new.get_centos_advisories()
      expect(xml_data).to match(/^<opt>/)
    end
  end

  # Actually load the CentOS advisories to make sure they work correctly.
  describe '#centos_advisories' do
    fixtures :packages

    it 'load known data and check state' do
      import = Import::Yum.new

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

  describe '#rhel_advisories' do
  end

  describe '#get_rhel_advisories' do
  end

  describe '#parse_cvrf' do
    it 'load known cvrf file and check data' do
      import = Import::Yum.new
      advisory = import.parse_cvrf('spec/data/cvrf/cvrf-rhsa-2016-0001.xml')

      expect(advisory['name']).to eq('RHSA-2016:0001')
      expect(advisory['description']).to eq('Red Hat Security Advisory: thunderbird security update')
      expect(advisory['severity']).to eq('Important')
      expect(advisory['kind']).to eq('Security Advisory')
      expect(advisory['os_family']).to eq('rhel')
      expect(advisory['reference']).to eq('https://rhn.redhat.com/errata/RHSA-2016-0001.html')
      expect(advisory['synopsis']).to eq('Several flaws were found in the processing of malformed web content. A web page containing malicious content could cause Thunderbird to crash or, potentially, execute arbitrary code with the privileges of the user running Thunderbird. ')
      expect(advisory['issue_date']).to eq('2016-01-05T06:33:00Z')
      expect(advisory['cves']).to eq(['CVE-2015-7201', 'CVE-2015-7205', 'CVE-2015-7212', 'CVE-2015-7213', 'CVE-2015-7214'])
      expect(advisory['packages']).to eq(['thunderbird-38.5.0-1.el5_11.x86_64.rpm', 'thunderbird-38.5.0-1.el5_11.i386.rpm', 'thunderbird-38.5.0-1.el6_7.x86_64.rpm', 'thunderbird-38.5.0-1.el6_7.i386.rpm', 'thunderbird-38.5.0-1.el7_2.x86_64.rpm', 'thunderbird-38.5.0-1.el7_2.i386.rpm'])
    end
  end

end
