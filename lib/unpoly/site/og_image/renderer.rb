require 'base64'

module Unpoly
  module Site
    class OgImage
      # Renders preview images in one headless Chrome: loads the template once, then fills
      # it with each image's data and takes a screenshot. The specs' Chrome and
      # chromedriver do the work (selenium-webdriver).
      #
      #   OgImage::Renderer.open { |renderer| File.binwrite('a.png', renderer.render(image.data)) }
      class Renderer
        def self.open
          renderer = new
          yield renderer
        ensure
          renderer&.quit
        end

        def initialize
          require 'selenium-webdriver'
          options = Selenium::WebDriver::Chrome::Options.new
          options.add_argument('--headless=new')
          options.add_argument('--hide-scrollbars')
          options.add_argument('--force-color-profile=srgb')
          # The template loads its fonts from next to itself.
          options.add_argument('--allow-file-access-from-files')
          begin
            # Without a path, Selenium Manager would download a Chrome or chromedriver it does
            # not find, or that does not match. A build installs nothing: it starts the
            # chromedriver on the PATH, which starts the installed Chrome.
            path = ENV['PATH'].split(File::PATH_SEPARATOR).map { |dir| File.join(dir, 'chromedriver') }.find { |file| File.executable?(file) } or
              raise 'no chromedriver on the PATH'
            service = Selenium::WebDriver::Service.chrome(path: path)
            @driver = Selenium::WebDriver.for(:chrome, options: options, service: service)
          rescue StandardError => e
            raise Error, "Rendering preview images needs Chrome and chromedriver (#{e.class}: #{e.message.lines.first&.strip}). " \
              'Install them, or build without preview images: SKIP_OG_IMAGES=1.'
          end
          @driver.execute_cdp('Emulation.setDeviceMetricsOverride', width: WIDTH, height: HEIGHT, deviceScaleFactor: 1, mobile: false)
          @driver.navigate.to("file://#{TEMPLATE}")
          @driver.execute_script("document.querySelector('.logo').innerHTML = arguments[0]", File.read(LOGO))
          # A font only loads once text uses it, so load them all before the first screenshot.
          @driver.execute_async_script('const done = arguments[0]; Promise.all(Array.from(document.fonts, (font) => font.load())).then(() => done())')
        end

        # data: OgImage#data, with string keys or symbols. Returns the PNG's bytes.
        def render(data)
          @driver.execute_script('fill(arguments[0])', data)
          Base64.decode64(@driver.execute_cdp('Page.captureScreenshot', format: 'png')['data'])
        end

        def quit
          @driver&.quit
        end
      end
    end
  end
end
