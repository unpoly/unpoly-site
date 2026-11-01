require 'open3'
require_relative 'errors'

module Unpoly
  module Site
    # The chromedriver that starts the installed Chrome for the preview images
    # (OgImage::Renderer), the feature specs (spec/support/capybara.rb) and bin/shoot.
    # It is a prerequisite (README): nothing here ever downloads a browser or driver.
    #
    #   Selenium::WebDriver.for(:chrome, options: options, service: Chromedriver.service)
    #
    # Without a driver path, selenium-webdriver runs Selenium Manager, which downloads a
    # Chrome and chromedriver when it finds none, or none that match, even with
    # SE_OFFLINE=true. A service with a path skips Selenium Manager.
    module Chromedriver
      class Error < Site::Error; end

      # Looked up in this order: ~/bin first, since a system package may leave an old
      # driver in /usr/bin.
      def self.candidates
        [File.join(Dir.home, 'bin', 'chromedriver'), *executables_on_path('chromedriver')]
      end

      # Where Chrome may be installed, so that we can tell its version. chromedriver finds
      # it by itself.
      def self.chrome_candidates
        [
          *%w[google-chrome google-chrome-stable chromium chromium-browser].flat_map { |name| executables_on_path(name) },
          '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        ]
      end

      # A new service for every driver, all with the same chromedriver.
      def self.service
        require 'selenium-webdriver'
        Selenium::WebDriver::Service.chrome(path: path)
      end

      # The first chromedriver found, if it matches the installed Chrome's major version.
      # Raises Error otherwise.
      def self.path
        @path ||= begin
          chrome = chrome_candidates.find { |file| File.executable?(file) }
          chrome_version = chrome && major_version(chrome)
          driver = candidates.find { |file| File.file?(file) && File.executable?(file) }
          driver_version = driver && major_version(driver)

          problem =
            if !chrome
              'Found no Chrome.'
            elsif !chrome_version
              "Could not tell the version of Chrome (#{chrome})."
            elsif !driver
              "Found no chromedriver in ~/bin or on the PATH, for Chrome #{chrome_version} (#{chrome})."
            elsif driver_version != chrome_version
              "Found #{driver} for Chrome #{driver_version || '(unknown version)'}, but Chrome #{chrome_version} is installed (#{chrome})."
            end

          if problem
            raise Error, <<~MESSAGE
              #{problem}
              The site drives Chrome through a chromedriver of the same major version, and never downloads either.
              Install Chrome and a matching chromedriver, preferably into ~/bin, which comes before the PATH:
              https://googlechromelabs.github.io/chrome-for-testing/
              To build the site without preview images, set SKIP_OG_IMAGES=1.
            MESSAGE
          end

          driver
        end
      end

      def self.major_version(executable)
        output, _status = Open3.capture2e(executable, '--version')
        output[/(\d+)\.\d+\.\d+/, 1]
      rescue SystemCallError
        nil
      end

      def self.executables_on_path(name)
        ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }
      end

      private_class_method :major_version, :executables_on_path
    end
  end
end
