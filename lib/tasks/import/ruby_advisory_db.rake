namespace :import do
  desc 'Import gem advisories from the ruby advisory database'
  task ruby_advisory_db: :environment do
    Import::Packages::Gems.new.update_source
    Import::Packages::Gems.new.import_advisories
  end
end
