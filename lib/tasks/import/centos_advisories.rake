namespace :import do
  desc 'Import centos advisories from the web'
  task centos_advisories: :environment do
    Import.new.centos_advisories()
  end
end
