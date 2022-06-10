require 'capybara/rspec'
require 'middleman-core'
require 'middleman-core/rack'

Capybara.register_driver :selenium do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless') unless ENV.key?('NO_HEADLESS')
  options.add_argument('--disable-infobars')
  options.add_option('w3c', false)
  options.add_emulation(device_metrics: { width: 1280, height: 960, touch: false })
  Capybara::Selenium::Driver.new(app, browser: :chrome , options: options)
end

Selenium::WebDriver.logger.level = :error

Capybara.javascript_driver = :selenium
# Capybara.server = :webrick

middleman_app = ::Middleman::Application.new do
  set :root, File.expand_path(File.join(File.dirname(__FILE__), '..'))
  set :environment, :development
  set :show_exceptions, false
end

Capybara.app = ::Middleman::Rack.new(middleman_app).to_app
