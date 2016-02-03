class ServerToPackage < ActiveRecord::Base
  belongs_to :package
  belongs_to :server
end
