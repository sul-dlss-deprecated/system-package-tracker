namespace :import do
  desc 'Import centos advisories from the web'
  task centos_advisories: :environment do
    Import::Packages::Yum::Centos.new.import_advisories
  end
end
