namespace :import do
  desc 'Import rhel advisories from the web'
  task rhel_advisories: :environment do
    Import.new.rhel_advisories()
  end
end
