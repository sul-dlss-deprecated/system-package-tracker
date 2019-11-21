source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.11.1'

# Database setup.
gem 'sqlite3', '~> 1.3.0'
gem 'pg', '0.20'
gem 'activerecord-import', '~> 1.0'

gem 'whenever', :require => false

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# The git gem is used to maintain a checkout of Ruby Gem advisories.
gem 'git'

# Access an IRB console on exception pages or by using <%= console %> in views
gem 'web-console', '~> 2.0', group: :development

# puppetdb-ruby queries for what nodes belong to a stack
gem 'puppetdb-ruby'

gem 'nokogiri', '>= 1.10.5'
gem 'loofah', '>= 2.3.1'

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
end

group :test do
  gem 'coveralls', require: false
end
