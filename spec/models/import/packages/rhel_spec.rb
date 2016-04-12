require 'rails_helper'

RSpec.describe Import::Packages::Yum::RHEL, type: :model do

  describe '#import_advisories' do
  end

  describe '#parse_cvrf' do
    it 'load known cvrf file and check data' do
      import = described_class.new
      advisory = import.parse_cvrf('spec/data/cvrf/cvrf-rhsa-2016-0001.xml')

      expect(advisory['name']).to eq('RHSA-2016:0001')
      expect(advisory['severity']).to eq('Important')
      expect(advisory['kind']).to eq('Security Advisory')
      expect(advisory['os_family']).to eq('rhel')
      expect(advisory['reference']).to eq('https://rhn.redhat.com/errata/RHSA-2016-0001.html')
      expect(advisory['issue_date']).to eq('2016-01-05T06:33:00Z')

      synopsis = 'Several flaws were found in the processing of malformed ' \
                 'web content. A web page containing malicious content could ' \
                 'cause Thunderbird to crash or, potentially, execute ' \
                 'arbitrary code with the privileges of the user running ' \
                 'Thunderbird. '
      expect(advisory['synopsis']).to eq(synopsis)

      desc = 'Red Hat Security Advisory: thunderbird security update'
      expect(advisory['description']).to eq(desc)

      cves = ['CVE-2015-7201', 'CVE-2015-7205', 'CVE-2015-7212',
              'CVE-2015-7213', 'CVE-2015-7214']
      expect(advisory['cves']).to eq(cves)

      packages = ['thunderbird-38.5.0-1.el5_11.x86_64.rpm',
                  'thunderbird-38.5.0-1.el5_11.i386.rpm',
                  'thunderbird-38.5.0-1.el6_7.x86_64.rpm',
                  'thunderbird-38.5.0-1.el6_7.i386.rpm',
                  'thunderbird-38.5.0-1.el7_2.x86_64.rpm',
                  'thunderbird-38.5.0-1.el7_2.i386.rpm']
      expect(advisory['packages']).to eq(packages)
    end
  end
end
