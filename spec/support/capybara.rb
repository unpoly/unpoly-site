RSpec.configure do |config|
  config.before(:all, type: :feature) do
    require 'capybara/rspec'
    require 'middleman-core'
    require 'middleman-core/rack'

    middleman_app = ::Middleman::Application.new do
      set :root, File.expand_path(File.join(File.dirname(__FILE__), '..'))
      set :environment, :development
      set :show_exceptions, false
    end

    Capybara.app = ::Middleman::Rack.new(middleman_app).to_app
  end
end
