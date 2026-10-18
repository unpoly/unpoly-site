source 'https://rubygems.org'

gem 'memoized'
gem 'andand'
gem 'nokogiri'

gem 'webrick'
gem "middleman", '<5'

gem "middleman-sprockets"
gem 'sass'
gem 'haml'
gem 'coffee-script'
gem 'terser'

gem 'naturally'

gem 'byebug'
gem 'rack'


# The build's link check and the rake tasks (search index, skill, URL checks). CI
# installs these, but not the deploy group below, which pulls a gem from git.
group :build do
  gem 'rake'
  gem 'html-proofer', '<4'
end

group :deploy do
  gem "capistrano", '<4'
  gem 'capistrano-middleman', require: false, git: 'https://github.com/makandra/capistrano-middleman.git'
end

group :test do
  gem 'rspec'
  gem 'capybara'
  gem 'selenium-webdriver', '>= 4'
  gem 'puma'
  # gem 'webrick'
end


gem "commonmarker", "~> 2.10"
