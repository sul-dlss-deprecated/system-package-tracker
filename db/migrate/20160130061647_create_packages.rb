class CreatePackages < ActiveRecord::Migration
  def change
    create_table :packages do |t|
      t.string :name
      t.string :version
      t.string :repository

      t.timestamps null: false
    end
    add_index :packages, :repository
  end
end
