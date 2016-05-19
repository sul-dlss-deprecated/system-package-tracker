class AddCveToAdvisories < ActiveRecord::Migration
  def change
    add_column :advisories, :cve, :string
  end
end
