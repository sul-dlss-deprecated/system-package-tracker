# Handle loading advisories into the database.  This just calls our class for
# handling centos advisory imports.
class AdvisoriesController < ApplicationController
  def index
    Import.new.centos_advisories()
  end
end
