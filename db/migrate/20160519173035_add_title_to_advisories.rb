class AddTitleToAdvisories < ActiveRecord::Migration[4.2]
  def change
    add_column :advisories, :title, :string
  end
end
