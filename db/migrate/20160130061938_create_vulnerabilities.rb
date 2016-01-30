class CreateVulnerabilities < ActiveRecord::Migration
  def change
    create_table :vulnerabilities do |t|
      t.string :advisory_id
      t.string :severity
      t.date :date_reported
      t.text :synopsis
      t.string :cve_id

      t.timestamps null: false
    end
    add_index :vulnerabilities, :severity
  end
end
