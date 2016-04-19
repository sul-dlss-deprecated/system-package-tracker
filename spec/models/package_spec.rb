require 'rails_helper'

RSpec.describe Package, type: :model do
  fixtures :packages
  it 'has the right number of entries' do
    expect(described_class.count).to eq(5)
  end
  it 'entries have the right name' do
    expect(described_class.where(name: 'xen').count).to eq(2)
  end
end
