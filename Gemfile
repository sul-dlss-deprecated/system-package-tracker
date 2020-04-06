source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '5.2.4.2'

# Database setup.
gem 'sqlite3', '~> 1.3.0'
gem 'pg', '0.20'
gem 'activerecord-import', '1.0.3'

gem 'whenever', :require => false

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'

gem 'json', '>= 2.3.0'

# The git gem is used to maintain a checkout of Ruby Gem advisories.
gem 'git'

# Access an IRB console on exception pages or by using <%= console %> in views
gem 'web-console', '~> 2.0', group: :development

# puppetdb-ruby queries for what nodes belong to a stack
gem 'puppetdb-ruby'

gem 'nokogiri', '>= 1.10.8'
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
