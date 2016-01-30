class CreateSystems < ActiveRecord::Migration
  def change
    create_table :systems do |t|
      t.string :hostname
      t.string :os

      t.timestamps null: false
    end
    add_index :systems, :os
  end
end
