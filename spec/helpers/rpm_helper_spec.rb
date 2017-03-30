require 'rails_helper'

RSpec.describe RpmHelper, type: :helper do
  describe 'version comparison' do

      # test cases munged directly from rpm's own
      # tests/rpmvercmp.at
      it { expect(helper.rpmvercmp("1.0", "1.0")).to eq(0) }
      it { expect(helper.rpmvercmp("1.0", "2.0")).to eq(-1) }
      it { expect(helper.rpmvercmp("2.0", "1.0")).to eq(1) }
      it { expect(helper.rpmvercmp("2.0.1", "2.0.1")).to eq(0) }
      it { expect(helper.rpmvercmp("2.0", "2.0.1")).to eq(-1) }
      it { expect(helper.rpmvercmp("2.0.1", "2.0")).to eq(1) }
      it { expect(helper.rpmvercmp("2.0.1a", "2.0.1a")).to eq(0) }
      it { expect(helper.rpmvercmp("2.0.1a", "2.0.1")).to eq(1) }
      it { expect(helper.rpmvercmp("2.0.1", "2.0.1a")).to eq(-1) }
      it { expect(helper.rpmvercmp("5.5p1", "5.5p1")).to eq(0) }
      it { expect(helper.rpmvercmp("5.5p1", "5.5p2")).to eq(-1) }
      it { expect(helper.rpmvercmp("5.5p2", "5.5p1")).to eq(1) }
      it { expect(helper.rpmvercmp("5.5p10", "5.5p10")).to eq(0) }
      it { expect(helper.rpmvercmp("5.5p1", "5.5p10")).to eq(-1) }
      it { expect(helper.rpmvercmp("5.5p10", "5.5p1")).to eq(1) }
      it { expect(helper.rpmvercmp("10xyz", "10.1xyz")).to eq(-1) }
      it { expect(helper.rpmvercmp("10.1xyz", "10xyz")).to eq(1) }
      it { expect(helper.rpmvercmp("xyz10", "xyz10")).to eq(0) }
      it { expect(helper.rpmvercmp("xyz10", "xyz10.1")).to eq(-1) }
      it { expect(helper.rpmvercmp("xyz10.1", "xyz10")).to eq(1) }
      it { expect(helper.rpmvercmp("xyz.4", "xyz.4")).to eq(0) }
      it { expect(helper.rpmvercmp("xyz.4", "8")).to eq(-1) }
      it { expect(helper.rpmvercmp("8", "xyz.4")).to eq(1) }
      it { expect(helper.rpmvercmp("xyz.4", "2")).to eq(-1) }
      it { expect(helper.rpmvercmp("2", "xyz.4")).to eq(1) }
      it { expect(helper.rpmvercmp("5.5p2", "5.6p1")).to eq(-1) }
      it { expect(helper.rpmvercmp("5.6p1", "5.5p2")).to eq(1) }
      it { expect(helper.rpmvercmp("5.6p1", "6.5p1")).to eq(-1) }
      it { expect(helper.rpmvercmp("6.5p1", "5.6p1")).to eq(1) }
      it { expect(helper.rpmvercmp("6.0.rc1", "6.0")).to eq(1) }
      it { expect(helper.rpmvercmp("6.0", "6.0.rc1")).to eq(-1) }
      it { expect(helper.rpmvercmp("10b2", "10a1")).to eq(1) }
      it { expect(helper.rpmvercmp("10a2", "10b2")).to eq(-1) }
      it { expect(helper.rpmvercmp("1.0aa", "1.0aa")).to eq(0) }
      it { expect(helper.rpmvercmp("1.0a", "1.0aa")).to eq(-1) }
      it { expect(helper.rpmvercmp("1.0aa", "1.0a")).to eq(1) }
      it { expect(helper.rpmvercmp("10.0001", "10.0001")).to eq(0) }
      it { expect(helper.rpmvercmp("10.0001", "10.1")).to eq(0) }
      it { expect(helper.rpmvercmp("10.1", "10.0001")).to eq(0) }
      it { expect(helper.rpmvercmp("10.0001", "10.0039")).to eq(-1) }
      it { expect(helper.rpmvercmp("10.0039", "10.0001")).to eq(1) }
      it { expect(helper.rpmvercmp("4.999.9", "5.0")).to eq(-1) }
      it { expect(helper.rpmvercmp("5.0", "4.999.9")).to eq(1) }
      it { expect(helper.rpmvercmp("20101121", "20101121")).to eq(0) }
      it { expect(helper.rpmvercmp("20101121", "20101122")).to eq(-1) }
      it { expect(helper.rpmvercmp("20101122", "20101121")).to eq(1) }
      it { expect(helper.rpmvercmp("2_0", "2_0")).to eq(0) }
      it { expect(helper.rpmvercmp("2.0", "2_0")).to eq(0) }
      it { expect(helper.rpmvercmp("2_0", "2.0")).to eq(0) }
      it { expect(helper.rpmvercmp("a", "a")).to eq(0) }
      it { expect(helper.rpmvercmp("a+", "a+")).to eq(0) }
      it { expect(helper.rpmvercmp("a+", "a_")).to eq(0) }
      it { expect(helper.rpmvercmp("a_", "a+")).to eq(0) }
      it { expect(helper.rpmvercmp("+a", "+a")).to eq(0) }
      it { expect(helper.rpmvercmp("+a", "_a")).to eq(0) }
      it { expect(helper.rpmvercmp("_a", "+a")).to eq(0) }
      it { expect(helper.rpmvercmp("+_", "+_")).to eq(0) }
      it { expect(helper.rpmvercmp("_+", "+_")).to eq(0) }
      it { expect(helper.rpmvercmp("_+", "_+")).to eq(0) }
      it { expect(helper.rpmvercmp("+", "_")).to eq(0) }
      it { expect(helper.rpmvercmp("_", "+")).to eq(0) }
      it { expect(helper.rpmvercmp("1.0~rc1", "1.0~rc1")).to eq(0) }
      it { expect(helper.rpmvercmp("1.0~rc1", "1.0")).to eq(-1) }
      it { expect(helper.rpmvercmp("1.0", "1.0~rc1")).to eq(1) }
      it { expect(helper.rpmvercmp("1.0~rc1", "1.0~rc2")).to eq(-1) }
      it { expect(helper.rpmvercmp("1.0~rc2", "1.0~rc1")).to eq(1) }
      it { expect(helper.rpmvercmp("1.0~rc1~git123", "1.0~rc1~git123")).to eq(0) }
      it { expect(helper.rpmvercmp("1.0~rc1~git123", "1.0~rc1")).to eq(-1) }
      it { expect(helper.rpmvercmp("1.0~rc1", "1.0~rc1~git123")).to eq(1) }
      it { expect(helper.rpmvercmp("1.0~rc1", "1.0arc1")).to eq(-1) }

      # non-upstream test cases
      it { expect(helper.rpmvercmp("405", "406")).to eq(-1) }
      it { expect(helper.rpmvercmp("1", "0")).to eq(1) }
    end

    describe 'package evr parsing' do

      it 'should parse full simple evr' do
        v = helper.rpm_parse_evr('0:1.2.3-4.el5')
        expect(v[:epoch]).to eq('0')
        expect(v[:version]).to eq('1.2.3')
        expect(v[:release]).to eq('4.el5')
      end

      it 'should parse version only' do
        v = helper.rpm_parse_evr('1.2.3')
        expect(v[:epoch]).to eq(nil)
        expect(v[:version]).to eq('1.2.3')
        expect(v[:release]).to eq(nil)
      end

      it 'should parse version-release' do
        v = helper.rpm_parse_evr('1.2.3-4.5.el6')
        expect(v[:epoch]).to eq(nil)
        expect(v[:version]).to eq('1.2.3')
        expect(v[:release]).to eq('4.5.el6')
      end

      it 'should parse release with git hash' do
        v = helper.rpm_parse_evr('1.2.3-4.1234aefd')
        expect(v[:epoch]).to eq(nil)
        expect(v[:version]).to eq('1.2.3')
        expect(v[:release]).to eq('4.1234aefd')
      end

      it 'should parse single integer versions' do
        v = helper.rpm_parse_evr('12345')
        expect(v[:epoch]).to eq(nil)
        expect(v[:version]).to eq('12345')
        expect(v[:release]).to eq(nil)
      end

      it 'should parse text in the epoch to 0' do
        v = helper.rpm_parse_evr('foo0:1.2.3-4')
        expect(v[:epoch]).to eq(nil)
        expect(v[:version]).to eq('1.2.3')
        expect(v[:release]).to eq('4')
      end

      it 'should parse revisions with text' do
        v = helper.rpm_parse_evr('1.2.3-SNAPSHOT20140107')
        expect(v[:epoch]).to eq(nil)
        expect(v[:version]).to eq('1.2.3')
        expect(v[:release]).to eq('SNAPSHOT20140107')
      end

      # test cases for PUP-682
      it 'should parse revisions with text and numbers' do
        v = helper.rpm_parse_evr('2.2-SNAPSHOT20121119105647')
        expect(v[:epoch]).to eq(nil)
        expect(v[:version]).to eq('2.2')
        expect(v[:release]).to eq('SNAPSHOT20121119105647')
      end

    end

    describe 'rpm evr comparison' do

      # currently passing tests
      it 'should evaluate identical version-release as equal' do
        v = helper.rpm_compareEVR({:epoch => '0', :version => '1.2.3', :release => '1.el5'},
                                    {:epoch => '0', :version => '1.2.3', :release => '1.el5'})
        expect(v).to eq(0)
      end

      it 'should evaluate identical version as equal' do
        v = helper.rpm_compareEVR({:epoch => '0', :version => '1.2.3', :release => nil},
                                    {:epoch => '0', :version => '1.2.3', :release => nil})
        expect(v).to eq(0)
      end

      it 'should evaluate identical version but older release as less' do
        v = helper.rpm_compareEVR({:epoch => '0', :version => '1.2.3', :release => '1.el5'},
                                    {:epoch => '0', :version => '1.2.3', :release => '2.el5'})
        expect(v).to eq(-1)
      end

      it 'should evaluate identical version but newer release as greater' do
        v = helper.rpm_compareEVR({:epoch => '0', :version => '1.2.3', :release => '3.el5'},
                                    {:epoch => '0', :version => '1.2.3', :release => '2.el5'})
        expect(v).to eq(1)
      end

      it 'should evaluate a newer epoch as greater' do
        v = helper.rpm_compareEVR({:epoch => '1', :version => '1.2.3', :release => '4.5'},
                                    {:epoch => '0', :version => '1.2.3', :release => '4.5'})
        expect(v).to eq(1)
      end

      # these tests describe PUP-1244 logic yet to be implemented
      it 'should evaluate any version as equal to the same version followed by release' do
        v = helper.rpm_compareEVR({:epoch => '0', :version => '1.2.3', :release => nil},
                                    {:epoch => '0', :version => '1.2.3', :release => '2.el5'})
        expect(v).to eq(0)
      end

      # test cases for PUP-682
      it 'should evaluate same-length numeric revisions numerically' do
        expect(helper.rpm_compareEVR({:epoch => '0', :version => '2.2', :release => '405'},
                                 {:epoch => '0', :version => '2.2', :release => '406'})).to eq(-1)
      end

    end

    describe 'version segment comparison' do

      it 'should treat two nil values as equal' do
        v = helper.compare_values(nil, nil)
        expect(v).to eq(0)
      end

      it 'should treat a nil value as less than a non-nil value' do
        v = helper.compare_values(nil, '0')
        expect(v).to eq(-1)
      end

      it 'should treat a non-nil value as greater than a nil value' do
        v = helper.compare_values('0', nil)
        expect(v).to eq(1)
      end
    end
end
