require 'rails_helper'

RSpec.describe Import::Packages::Yum::RHEL, type: :model do

  describe '#import_source' do
    it 'download and bunzip RHEL oval data' do
      stub_const('Import::Packages::Yum::RHEL::PROXY_ADDR', '')
      stub_const('Import::Packages::Yum::RHEL::OVAL_LOCAL', 'spec/data/tmp/oval')
      import = described_class.new
      import.import_source

      expect(File.exists?(Import::Packages::Yum::RHEL::OVAL_LOCAL)).to be true
    end
  end

  describe '#parse_oval' do
    it 'load known oval file and check data' do
      import = described_class.new
      advisories = import.parse_oval('spec/data/oval.test')

      expect(advisories.count).to eq(1)
      advisory = advisories[0]

      name = 'RHSA-2015:0672: bind security update (Moderate)'
      expect(advisory['name']).to eq(name)
      expect(advisory['severity']).to eq('Moderate')
      expect(advisory['kind']).to eq('Security Advisory')
      expect(advisory['os_family']).to eq('rhel')
      #expect(advisory['reference']).to eq('https://rhn.redhat.com/errata/RHSA-2016-0001.html')
      expect(advisory['issue_date']).to eq('2015-03-10')

      # Synopsis is nothing on RHEL.
      expect(advisory['synopsis']).to eq('')
      desc = "The Berkeley Internet Name Domain (BIND) is an implementation of the Domain\n" \
        "Name System (DNS) protocols. BIND includes a DNS server (named); a resolver\n" \
        "library (routines for applications to use when interfacing with DNS); and\n" \
        "tools for verifying that the DNS server is operating correctly.\n" \
        "\n" \
        "A flaw was found in the way BIND handled trust anchor management. A remote\n" \
        "attacker could use this flaw to cause the BIND daemon (named) to crash\n" \
        "under certain conditions. (CVE-2015-1349)\n" \
        "\n" \
        "Red Hat would like to thank ISC for reporting this issue.\n" \
        "\n" \
        "All bind users are advised to upgrade to these updated packages, which\n" \
        "contain a backported patch to correct this issue. After installing the\n" \
        "update, the BIND daemon (named) will be restarted automatically."
      expect(advisory['description']).to eq(desc)

      packages = %w(bind-32:9.8.2-0.30.rc1.el6_6.2.x86_64.rpm
                    bind-32:9.8.2-0.30.rc1.el6_6.2.i386.rpm
                    bind-chroot-32:9.8.2-0.30.rc1.el6_6.2.x86_64.rpm
                    bind-chroot-32:9.8.2-0.30.rc1.el6_6.2.i386.rpm
                    bind-devel-32:9.8.2-0.30.rc1.el6_6.2.x86_64.rpm
                    bind-devel-32:9.8.2-0.30.rc1.el6_6.2.i386.rpm
                    bind-libs-32:9.8.2-0.30.rc1.el6_6.2.x86_64.rpm
                    bind-libs-32:9.8.2-0.30.rc1.el6_6.2.i386.rpm
                    bind-sdb-32:9.8.2-0.30.rc1.el6_6.2.x86_64.rpm
                    bind-sdb-32:9.8.2-0.30.rc1.el6_6.2.i386.rpm
                    bind-utils-32:9.8.2-0.30.rc1.el6_6.2.x86_64.rpm
                    bind-utils-32:9.8.2-0.30.rc1.el6_6.2.i386.rpm
                    bind-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-chroot-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-chroot-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-devel-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-devel-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-libs-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-libs-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-libs-lite-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-libs-lite-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-license-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-license-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-lite-devel-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-lite-devel-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-sdb-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-sdb-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-sdb-chroot-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-sdb-chroot-32:9.9.4-18.el7_1.1.i386.rpm
                    bind-utils-32:9.9.4-18.el7_1.1.x86_64.rpm
                    bind-utils-32:9.9.4-18.el7_1.1.i386.rpm
                  )
      expect(advisory['packages']).to eq(packages)
    end
  end
end
