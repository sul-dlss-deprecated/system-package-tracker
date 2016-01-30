class System < ActiveRecord::Base
  has_and_belongs_to_many :packages
  has_many :vulnerabilities, through: :packages
end
