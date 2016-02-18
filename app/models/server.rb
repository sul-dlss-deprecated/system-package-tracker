class Server < ActiveRecord::Base
  has_many :servers_to_packages, class_name: 'ServerToPackage'
  has_many :packages, through: :servers_to_packages

  has_many :servers_to_pending_packages, -> {where status: 'pending'}, class_name: 'ServerToPackage'
  has_many :pending_packages, through: :servers_to_pending_packages, class_name: 'Package', source: :package

  has_many :servers_to_installed_packages, -> {where status: 'installed'}, class_name: 'ServerToPackage'
  has_many :installed_packages, through: :servers_to_installed_packages, class_name: 'Package', source: :package
end
