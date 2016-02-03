class AdvisoryToPackage < ActiveRecord::Base
  belongs_to :package
  belongs_to :advisory
end
