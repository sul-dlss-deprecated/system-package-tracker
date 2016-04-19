require 'rails_helper'

RSpec.describe Import::Packages::Yum, type: :model do

  # Tests for parsing a major release version from an RPM name.
  describe "#centos_package_major_release" do
    it "finds the right major release for an el* package" do
      rpm = 'xen-3.0.3-135.el5_8.2.i386.rpm'
      expect(described_class.new.centos_package_major_release(rpm)).to eq(5)
    end
    it "finds the right major release for an centos* package" do
      rpm = 'up2date-4.4.5.6-2.centos4.i386.rpm'
      expect(described_class.new.centos_package_major_release(rpm)).to eq(4)
    end
    it "finds the right major release for an rhel* package" do
      rpm = 'xloadimage-4.1-34.RHEL4.x86_64.rpm'
      expect(described_class.new.centos_package_major_release(rpm)).to eq(4)
    end
    it "finds no major release for a package without" do
      rpm = 'nfs-utils-1.0.9-60.i386.rpm'
      expect(described_class.new.centos_package_major_release(rpm)).to eq(0)
    end
  end

  # Tests for seeing if a package is in a list of major release versions.
  describe '#used_release?' do
    it "package is in default major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      expect(described_class.new.used_release?(packages)).to be true
    end
    it "package is outside of default major releases" do
      packages = ['xen-3.0.3-135.el4_8.2.i386.rpm']
      expect(described_class.new.used_release?(packages)).to be false
    end
    it "package is in specific major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      releases = [5, 6]
      expect(described_class.new.used_release?(packages, releases)).to be true
    end
    it "package is outside of specific major releases" do
      packages = ['xen-3.0.3-135.el5_8.2.i386.rpm']
      releases = [6, 7]
      expect(described_class.new.used_release?(packages, releases)).to be false
    end
  end
end
