require 'rails_helper'

RSpec.describe Server, type: :model do
  fixtures :servers
  it "has the right number of entries" do
    expect(Server.count).to eq(2)
  end
  it "finds the right name for an entry" do
    expect(Server.where(hostname: 'test.stanford.edu').count).to eq(1)
  end
end
