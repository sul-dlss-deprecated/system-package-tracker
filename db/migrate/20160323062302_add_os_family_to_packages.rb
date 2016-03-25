# Add the OS family to packages, so that we can track the RHEL and centos
# packages against separate vulnerabilities.
class AddOsFamilyToPackages < ActiveRecord::Migration
  def change
    add_column :packages, :os_family, :string
    remove_index :packages, column: [:name, :version, :arch, :provider]
    add_index :packages, [:name, :version, :arch, :provider, :os_family],
              unique: true, name: 'unique_pkg'
  end
end
