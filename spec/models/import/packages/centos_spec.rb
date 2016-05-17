require 'rails_helper'

RSpec.describe Import::Packages::Yum::Centos, type: :model do
  # Get CentOS advisory XML contents.
  describe "#update_source" do
    it "fetch centos advisories" do
      stub_const('Import::Packages::Yum::Centos::PROXY_ADDR', '')
      xml_data = described_class.new.update_source
      expect(xml_data).to match(/^<opt>/)
    end
  end

  # Actually load the CentOS advisories to make sure they work correctly.
  describe "#import_advisories" do
    fixtures :packages

    it "load known data and check state" do
      import = described_class.new

      # Set up a known subset of the advisories XML.
      xml = '<opt><CESA-2012--0370 description="Not available" from="centos-announce@centos.org" issue_date="2012-03-07 23:16:09" multirelease="1" notes="Not available" product="CentOS Linux" references="https://rhn.redhat.com/errata/RHSA-2012-0370.html http://lists.centos.org/pipermail/centos-announce/2012-March/018479.html" release="1" severity="Important" solution="Not available" synopsis="Important CentOS xen security and bug fix update" topic="Not available" type="Security Advisory"><os_arch>i386</os_arch><os_arch>x86_64</os_arch><os_release>5</os_release><packages>xen-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-3.0.3-135.el5_8.2.src.rpm</packages><packages>xen-3.0.3-135.el5_8.2.x86_64.rpm</packages><packages>xen-devel-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-devel-3.0.3-135.el5_8.2.x86_64.rpm</packages><packages>xen-libs-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-libs-3.0.3-135.el5_8.2.x86_64.rpm</packages></CESA-2012--0370><meta><author>Steve Meier</author><license>Free for non-commercial use</license><disclaimer>This software is provided AS IS. There are no guarantees. It might kill your cat.</disclaimer><timestamp>Thu Feb 11 09:08:36 UTC 2016</timestamp></meta></opt>'
      allow(import).to receive(:update_source).and_return(xml)

      import.import_advisories

      # Make sure advisory exists and has only the one correct package.
      adv = Advisory.find_by(name: 'CESA-2012--0370')
      expect(adv.name).to eq('CESA-2012--0370')
      expect(adv.packages.size).to eq(1)
      expect(adv.packages.first.name).to eq('xen')
      expect(adv.packages.first.version).to eq('3.0.0-1.el5')
    end
  end
end
