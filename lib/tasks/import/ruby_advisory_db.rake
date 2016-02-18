namespace :import do
  desc 'Import gem advisories from the ruby advisory database'
  task ruby_advisory_db: :environment do
    Import.new.ruby_advisories()
  end
end
