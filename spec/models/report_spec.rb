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

  describe "#load_schedule" do
    it "has output match" do
      puppet_response = [
        { 'certname' => 'dev.stanford.edu', 'stack_level' => 'dev'},
        { 'certname' => 'qa.stanford.edu', 'stack_level' => 'qa'},
        { 'certname' => 'stage.stanford.edu', 'stack_level' => 'stage'},
        { 'certname' => 'test.stanford.edu', 'stack_level' => 'test'},
        { 'certname' => 'prod.stanford.edu', 'stack_level' => 'prod'},
        { 'certname' => 'week4.stanford.edu', 'upgrade_week' => 4}
      ]
      report = described_class.new
      allow(report).to receive(:get_puppet_facts).and_return(puppet_response)
      schedule = report.load_puppet_schedule
      expect(schedule.keys.count).to eq(4)
      expect(schedule[1].sort).to eq(['dev.stanford.edu', 'qa.stanford.edu'])
      expect(schedule[2].sort).to eq(['stage.stanford.edu', 'test.stanford.edu'])
      expect(schedule[3].sort).to eq(['prod.stanford.edu'])
      expect(schedule[4]).to eq(['week4.stanford.edu'])
    end
  end
end
