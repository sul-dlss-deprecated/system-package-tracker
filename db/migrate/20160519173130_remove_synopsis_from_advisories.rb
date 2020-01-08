class RemoveSynopsisFromAdvisories < ActiveRecord::Migration[4.2]
  def change
    remove_column :advisories, :synopsis, :string
  end
end
