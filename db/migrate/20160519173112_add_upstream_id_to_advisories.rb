class AddUpstreamIdToAdvisories < ActiveRecord::Migration
  def change
    add_column :advisories, :upstream_id, :string
  end
end
