# Intermediate class for mapping servers and packages.
class ServerToPackage < ActiveRecord::Base
  belongs_to :package
  belongs_to :server
end
