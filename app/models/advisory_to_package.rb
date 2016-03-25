# Intermediate class for mapping advisories and packages.
class AdvisoryToPackage < ActiveRecord::Base
  belongs_to :package
  belongs_to :advisory
end
