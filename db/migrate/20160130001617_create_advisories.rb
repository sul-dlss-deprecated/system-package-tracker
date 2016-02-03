class CreateAdvisories < ActiveRecord::Migration
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

      t.timestamps null: false
    end
    add_index :advisories, [:name, :os_family], :unique => true

  end
end
