require 'rails_helper'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_hosts 'raw.githubusercontent.com', 'www.redhat.com'
end

RSpec.describe Stack, type: :model do

  it 'has a PuppetDB client' do
    expect(Stack.client).to be_kind_of(PuppetDB::Client)
  end

  it 'knows where puppetdb is' do
    expect(Stack.endpoint).to eq('http://sulpuppet-db.stanford.edu:8080')
  end

  it 'knows a machine is in a stack', :vcr do
    expect(Stack.members('exhibits')).to include('exhibits-prod-a.stanford.edu')
  end

  it 'knows all stack names', :vcr do
    expect(Stack.all).to eq(['sulreports', 'puppet', 'exhibits', 'elk'])
  end

  it 'knows of empty stacks', :vcr do
    expect(Stack.empties).to eq([])
  end

  it 'knows the difference between orphans and non-orphans', :vcr do
    orphans = Stack.orphans
    expect(orphans).not_to include('exhibits-prod-a.stanford.edu')
    expect(orphans).to include('argo-prod-b.stanford.edu')
  end
end
