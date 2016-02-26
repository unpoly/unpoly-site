require 'lib/ext/rack-test/support_colons_in_path'
require 'lib/upjs/guide'
require 'lib/upjs/example'

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

# page '/examples/*', layout: 'example'

page '*', layout: 'guide'

# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
Upjs::Guide.current.klasses.each do |klass|
  path = "#{klass.guide_path}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Proxy: #{path}"
  proxy path, "/klass.html", locals: { klass_name: klass.name }, ignore: true
end

Upjs::Guide.current.all_feature_guide_ids.each do |guide_id|
  path = "/#{guide_id}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Proxy: #{path}"
  proxy path, "/symbol.html", locals: { guide_id: guide_id }, ignore: true
end

Upjs::Example.all.each do |example|

  proxy example.index_path, "examples/index.html", locals: { example: example }, layout: false, ignore: true, directory_index: false

  example.stylesheets.each do |asset|
    puts "Example stylesheet: #{asset.path}"
    proxy asset.path, "/examples/stylesheet", locals: { asset: asset }, layout: false, ignore: true, directory_index: false
  end

  example.javascripts.each do |asset|
    puts "Example javascripts: #{asset.path}"
    proxy asset.path, "/examples/javascript.js", locals: { asset: asset }, layout: false, ignore: true, directory_index: false
  end

  example.pages.each do |asset|
    puts "Example pages: #{asset.path}"
    proxy asset.path, "/examples/page.html", locals: { asset: asset }, layout: false, ignore: true, directory_index: false
  end

end

# ignore '/klass.html.erb'

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
    doc = Kramdown::Document.new(text,
      input: 'GFM',
      remove_span_html_tags: true,
      enable_coderay: false,
      smart_quotes: ["apos", "apos", "quot", "quot"],
      hard_wrap: false
    )
    # Blindly remove any HTML tag from the document, including "span" elements
    # (see option above). This will NOT remove HTML tags from code examples.
    doc.to_remove_html_tags
    doc.to_html
  end

  def markdown_prose(text)
    "<div class='prose'>#{markdown(text)}</div>"
  end

  def window_title
    page_title = @page_title || current_page.data.title

    if page_title.present?
      "#{page_title} - Unpoly Guide"
    else
      "Unpoly Guide"
    end
  end
  
  def upjs_library_size
    require 'active_support/gzip'
    source = ''
    source << File.read('vendor/upjs-local/dist/up.min.js') +
    source << File.read('vendor/upjs-local/dist/up.min.css')
    (ActiveSupport::Gzip.compress(source).length / 1024).round
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
  sprockets.append_path File.expand_path('vendor/upjs-local/lib/assets/javascripts')
  sprockets.append_path File.expand_path('vendor/upjs-local/lib/assets/stylesheets')
  # sprockets.append_path File.expand_path('../upjs/lib/assets/styless')
end

# Build-specific configuration
configure :build do
  # For example, change the Compass output style for deployment
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript

  # Enable cache buster
  # activate :asset_hash

  # Use relative URLs
  # activate :relative_assets

  # Or use a different image path
  # set :http_prefix, "/Content/images/"
end
