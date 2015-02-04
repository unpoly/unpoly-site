require 'lib/upjs/guide'

###
# Compass
###

# Change Compass configuration
# compass_config do |config|
#   config.output_style = :compact
# end

###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end


# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
Upjs::Guide.current.klasses.each do |klass|
  path = "/#{klass.guide_filename('.html')}"
  puts "Proxy: #{path}"
  proxy path, "/klass.html", locals: { klass_name: klass.name }, ignore: true
end

# proxy "/this-page-has-no-template.html", "/template-file.html", :locals => {
#  :which_fake_page => "Rendering a fake page with a local variable" }

###
# Helpers
###

# Automatic image dimensions on image_tag helper
# activate :automatic_image_sizes

activate :directory_indexes

# Reload the browser automatically whenever files change
# configure :development do
#   activate :livereload
# end

# Methods defined in the helpers block are available in templates
helpers do

  def guide
    @guide ||= Upjs::Guide.current
  end

  def markdown(text)
    doc = Kramdown::Document.new(text, input: 'GFM', remove_span_html_tags: true, enable_coderay: false)
    # Blindly remove any HTML tag from the document, including "span" elements
    # (see option above). This will NOT remove HTML tags from code examples.
    doc.to_remove_html_tags
    doc.to_html
  end

  def window_title
    page_title = current_page.data.title

    if page_title.present?
      "#{page_title} - Up.js Guide"
    else
      "Up.js Guide"
    end
  end

end

set :css_dir, 'stylesheets'

set :js_dir, 'javascripts'

set :images_dir, 'images'

ready do
  paths = Dir["vendor/*"].sort_by { |dir| -dir.size }
  paths.each do |path|
    puts "APPENDING SPROCKET PATH: #{path}"
    sprockets.append_path File.expand_path(path)
  end
end

# Build-specific configuration
configure :build do
  # For example, change the Compass output style for deployment
  # activate :minify_css

  # Minify Javascript on build
  # activate :minify_javascript

  # Enable cache buster
  # activate :asset_hash

  # Use relative URLs
  # activate :relative_assets

  # Or use a different image path
  # set :http_prefix, "/Content/images/"
end
