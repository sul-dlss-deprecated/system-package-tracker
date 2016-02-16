class CreateServerToPackages < ActiveRecord::Migration
  def change
    create_table :server_to_packages do |t|
      t.integer :server_id
      t.integer :package_id
      t.string :status

      t.timestamps null: false
    end

  end
end
