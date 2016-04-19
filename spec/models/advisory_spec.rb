require 'rails_helper'

RSpec.describe Advisory, type: :model do
  fixtures :advisories
  it "has the right number of entries" do
    expect(described_class.count).to eq(1)
  end
  it "entries have the right name" do
    expect(described_class.where(name: 'CESA-2012--0001').count).to eq(1)
  end
end
