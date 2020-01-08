# Initial creation of the table associating advisories with affected packages.
class CreateAdvisoryToPackages < ActiveRecord::Migration[4.2]
  def change
    create_table :advisory_to_packages do |t|
      t.integer :package_id
      t.integer :advisory_id

      t.timestamps null: false
    end
  end
end
