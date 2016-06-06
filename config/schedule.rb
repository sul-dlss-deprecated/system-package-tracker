# This defines cron jobs with the whenever gem.

# Run each of our import tasks in sequence.
every '30 2 * * *' do
   rake 'import:servers'
   rake 'import:centos_advisories'
   rake 'import:rhel_advisories'
   rake 'import:ruby_advisory_db'
end
