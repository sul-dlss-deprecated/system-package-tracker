class Package < ActiveRecord::Base
  has_many :advisories_to_packages, class_name: 'AdvisoryToPackage'
  has_many :advisories, through: :advisories_to_packages

  has_many :servers_to_packages, class_name: 'ServerToPackage'
  has_many :servers, through: :servers_to_packages
end
