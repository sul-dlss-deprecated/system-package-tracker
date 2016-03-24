namespace :import do
  desc 'Import gem advisories from the ruby advisory database'
  task ruby_advisory_db: :environment do
    Import::Gems.new.update_source()
    Import::Gems.new.ruby_advisories()
  end
end
