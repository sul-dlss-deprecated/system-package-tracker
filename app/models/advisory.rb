# Advisories and how they map to the packages that they affect.
class Advisory < ActiveRecord::Base
  has_many :advisories_to_packages, class_name: 'AdvisoryToPackage'
  has_many :packages, through: :advisories_to_packages
end
