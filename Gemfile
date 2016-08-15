source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.7.1'

# Database setup.
gem 'sqlite3'
gem 'pg'
gem 'activerecord-import'

gem 'whenever', :require => false

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# The RPM gem is needed for version parsing.
gem 'rpm'

# The git gem is used to maintain a checkout of Ruby Gem advisories.
gem 'git'

# Access an IRB console on exception pages or by using <%= console %> in views
gem 'web-console', '~> 2.0', group: :development

group :deployment do
  gem 'capistrano', '~> 3.0'
  gem 'capistrano-rails' # or other gems as appropriate
  gem 'capistrano-rvm'
  gem 'capistrano-bundler'
  gem 'dlss-capistrano'
end

group :development, :test do
  # Call 'byebug' anywhere in the code to get a debugger console
  gem 'byebug'
  gem 'rspec-rails', '~> 3.0'
  gem 'dlss_cops'
end

group :test do
  gem 'coveralls', require: false
end
