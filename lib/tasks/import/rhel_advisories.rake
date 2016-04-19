namespace :import do
  desc 'Import rhel advisories from the web'
  task rhel_advisories: :environment do
    Import::Packages::Yum::RHEL.new.import_source
    Import::Packages::Yum::RHEL.new.import_advisories
  end
end
