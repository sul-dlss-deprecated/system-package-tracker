class Server < ActiveRecord::Base
  has_many :servers_to_packages, class_name: 'ServerToPackage'
  has_many :packages, through: :servers_to_packages
end
