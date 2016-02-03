class CreatePackages < ActiveRecord::Migration
  def change
    create_table :packages do |t|
      t.string :name
	    t.string :version
	    t.string :arch
	    t.string :provider

      t.index :name

      t.timestamps null: false
    end
    add_index :packages, [:name, :version, :arch, :provider], :unique => true
  end
end
