require 'rails_helper'

RSpec.describe Package, type: :model do
  fixtures :packages
  it "has the right number of entries" do
    expect(Package.count).to eq(2)
  end
  it "entries have the right name" do
    expect(Package.where(name: 'xen').count).to eq(2)
  end
end
