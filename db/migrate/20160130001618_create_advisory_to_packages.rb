class CreateAdvisoryToPackages < ActiveRecord::Migration
  def change
    create_table :advisory_to_packages do |t|
      t.string :package_id
      t.string :advisory_id

      t.timestamps null: false
    end

  end
end
