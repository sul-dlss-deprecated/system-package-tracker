class RemoveSynopsisFromAdvisories < ActiveRecord::Migration
  def change
    remove_column :advisories, :synopsis, :string
  end
end
