set :deploy_host, 'sulreports'
set :user, 'reporting'
set :deploy_to, '/home/reporting/server-reports'
server "#{fetch(:deploy_host)}.stanford.edu", user: fetch(:user), roles: %w{web db app}

Capistrano::OneTimeKey.generate_one_time_key!

set :rails_env, 'production'
