class CreateServerToPackages < ActiveRecord::Migration
  def change
    create_table :server_to_packages do |t|
      t.string :server_id
	    t.string :package_id

      t.timestamps null: false
    end

  end
end
