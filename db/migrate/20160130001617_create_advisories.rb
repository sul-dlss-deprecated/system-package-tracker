# Initial creation of the table containing package advisory data.
class CreateAdvisories < ActiveRecord::Migration[4.2]
  def change
    create_table :advisories do |t|
      t.string :name
      t.string :description
      t.string :issue_date
      t.string :references
      t.string :kind
      t.string :synopsis
      t.string :severity
      t.string :os_family
      t.text :fix_versions

      t.timestamps null: false
    end
    add_index :advisories, [:name, :os_family], unique: true
  end
end
