class AddUpstreamIdToAdvisories < ActiveRecord::Migration[4.2]
  def change
    add_column :advisories, :upstream_id, :string
  end
end
