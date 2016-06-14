# Packages and how they map both to advisories released for them, and to the
# servers on which they are installed.
class Package < ActiveRecord::Base
  has_many :advisories_to_packages, class_name: 'AdvisoryToPackage'
  has_many :advisories, through: :advisories_to_packages

  has_many :servers_to_packages, class_name: 'ServerToPackage'
  has_many :servers, through: :servers_to_packages

  has_many :servers_to_pending_packages, -> { where status: 'pending' },
                                         class_name: 'ServerToPackage'
  has_many :pending_packages, through: :servers_to_pending_packages,
                              class_name: 'Server', source: :server
end
