require 'rails_helper'

RSpec.describe AdvisoriesController, type: :controller do
  describe '#save_advisory' do
    it 'fetch centos advisories' do
      xml_data = AdvisoriesController.new.get_centos_advisories()
      expect(xml_data).to match(/^<opt>/)
    end
  end

  describe '#index' do
    fixtures :packages

    it 'load known data and check state' do
      advisories = AdvisoriesController.new

      # Set up a known subset of the advisories XML.
      #advisories = instance_double('AdvisoriesController')
      xml = '<opt><CESA-2012--0370 description="Not available" from="centos-announce@centos.org" issue_date="2012-03-07 23:16:09" multirelease="1" notes="Not available" product="CentOS Linux" references="https://rhn.redhat.com/errata/RHSA-2012-0370.html http://lists.centos.org/pipermail/centos-announce/2012-March/018479.html" release="1" severity="Important" solution="Not available" synopsis="Important CentOS xen security and bug fix update" topic="Not available" type="Security Advisory"><os_arch>i386</os_arch><os_arch>x86_64</os_arch><os_release>5</os_release><packages>xen-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-3.0.3-135.el5_8.2.src.rpm</packages><packages>xen-3.0.3-135.el5_8.2.x86_64.rpm</packages><packages>xen-devel-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-devel-3.0.3-135.el5_8.2.x86_64.rpm</packages><packages>xen-libs-3.0.3-135.el5_8.2.i386.rpm</packages><packages>xen-libs-3.0.3-135.el5_8.2.x86_64.rpm</packages></CESA-2012--0370><meta><author>Steve Meier</author><license>Free for non-commercial use</license><disclaimer>This software is provided AS IS. There are no guarantees. It might kill your cat.</disclaimer><timestamp>Thu Feb 11 09:08:36 UTC 2016</timestamp></meta></opt>'
      allow(advisories).to receive(:get_centos_advisories).and_return(xml)

      advisories.index

      # TODO: Check to make sure the package is the correct one.

      # Make sure advisory exists and has only the one correct package.
      adv = Advisory.find_by(name: 'CESA-2012--0370')
      expect(adv.name).to eq('CESA-2012--0370')
      expect(adv.advisories_to_packages.size).to eq(1)
    end
  end

end
