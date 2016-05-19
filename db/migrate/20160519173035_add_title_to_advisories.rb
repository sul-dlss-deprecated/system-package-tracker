class AddTitleToAdvisories < ActiveRecord::Migration
  def change
    add_column :advisories, :title, :string
  end
end
