require 'rails_helper'

RSpec.describe Report, type: :model do
  # This is a short-term fix for my fixtures not being loaded on test server.
  # I'll debug what's wrong after I'm done here.
  require 'active_record/fixtures'
  ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("spec", "fixtures"),
                                           "servers")
  ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("spec", "fixtures"),
                                           "packages")
  ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("spec", "fixtures"),
                                           "advisories")
  ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("spec", "fixtures"),
                                           "advisory_to_packages")
  ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("spec", "fixtures"),
                                           "server_to_packages")

  fixtures :servers
  fixtures :packages
  fixtures :advisories
  fixtures :advisory_to_packages
  fixtures :server_to_packages

  describe "#installed_packages" do
    it "has output match" do
      stub_const('Report::LAST_CHECKIN', 10000)

      report_test = YAML.load(File.open("spec/data/output/servers.yml"))
      report = described_class.new.installed_packages
      expect(report.keys.count).to eq(2)
      expect(report).to include(report_test)
    end
  end

  describe "#advisories" do
    it "has output match" do
      stub_const('Report::LAST_CHECKIN', 10000)

      report_test = YAML.load(File.open("spec/data/output/advisories.yml"))
      report = described_class.new.advisories
      expect(report.keys.count).to eq(1)

      # Remove two timestamp fields so that we're not triggering on them when
      # we do a full compare.
      report["example.stanford.edu"]["xen"]["3.0.0-1.el5"][0]
        .delete("updated_at")
      report["example.stanford.edu"]["xen"]["3.0.0-1.el5"][0]
        .delete("created_at")

      expect(report).to include(report_test)
    end
  end
end
