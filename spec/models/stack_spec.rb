require 'rails_helper'

RSpec.describe Stack, type: :model do

  it 'knows where puppetdb is' do
    expect(Stack.endpoint).to eq('http://sulpuppet-db.stanford.edu:8080')
  end

  it 'knows a machine is in a stack' do
    allow(Stack).to receive(:members).and_return(['exhibits-prod-a.stanford.edu'])
    expect(Stack.members('exhibits')).to include('exhibits-prod-a.stanford.edu')
  end

end
