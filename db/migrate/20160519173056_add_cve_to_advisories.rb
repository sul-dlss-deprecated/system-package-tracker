class AddCveToAdvisories < ActiveRecord::Migration[4.2]
  def change
    add_column :advisories, :cve, :string
  end
end
