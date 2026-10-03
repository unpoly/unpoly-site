# Must be loaded before the first example, so that Capybara's own `before` hook
# is registered in time to switch the driver for examples tagged `js: true`.
require 'capybara/rspec'

def register_chrome_driver(name, width:, height:)
  Capybara.register_driver name do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new') unless ENV.key?('NO_HEADLESS')
    options.add_argument('--disable-infobars')
    options.add_emulation(device_metrics: { width: width, height: height, touch: false })
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end
end

register_chrome_driver(:selenium, width: 1280, height: 960)

# Below $bp-sidebar, where the burger replaces the sidebar and the header's search pill.
# Chrome's device emulation ignores window resizing, so a narrow viewport needs its own
# driver rather than a resize inside the example. Use with `driver: :selenium_phone`.
register_chrome_driver(:selenium_phone, width: 390, height: 800)

# Just above $bp-sidebar, where the header is at its tightest.
register_chrome_driver(:selenium_small_desktop, width: 1100, height: 900)

# Wide screens, where the text column grows (1500) and reaches its cap (1920).
register_chrome_driver(:selenium_wide, width: 1500, height: 900)
register_chrome_driver(:selenium_widest, width: 1920, height: 1080)

Selenium::WebDriver.logger.level = :error

Capybara.javascript_driver = :selenium

# The menu is a ~370 KB fragment that the development server needs more than a second
# to render, so waiting for it can exceed Capybara's default of 2 seconds.
Capybara.default_max_wait_time = 8
# Capybara.server = :webrick

# Booting Middleman takes a moment, so we only do it once, and only when a feature
# spec actually runs.
def configure_capybara_once
  return if Capybara.app

  require 'middleman-core'
  require 'middleman-core/rack'

  middleman_app = ::Middleman::Application.new do
    set :root, File.expand_path(File.join(File.dirname(__FILE__), '..'))
    set :environment, :development
    set :show_exceptions, false
  end

  Capybara.app = ::Middleman::Rack.new(middleman_app).to_app
end

RSpec.configure do |config|
  config.before(:each, type: :feature) do
    configure_capybara_once
  end
end

