# Every page with a Markdown twin offers it in the ai-tools corner of its title row
# (page_title in config.rb), checked over the last build because there are hundreds of
# such pages. Skipped without a build, as in CI.
describe 'the built site' do

  BUILD_DIR = File.expand_path('../../build', __dir__)

  it 'gives every page with a Markdown twin an ai-tools corner, and the landing page none' do
    skip 'no build (run `bundle exec middleman build`)' unless File.file?(File.join(BUILD_DIR, 'index.md'))

    twins = Dir.glob('**/*.md', base: BUILD_DIR).reject { |file| file.start_with?('skills/') || file == 'index.md' }
    expect(twins.size).to be > 500

    missing = twins.reject do |twin|
      html = File.join(BUILD_DIR, twin.delete_suffix('.md'), 'index.html')
      File.file?(html) && File.read(html).include?('class="ai-tools"')
    end
    expect(missing).to eq([])
    expect(File.read(File.join(BUILD_DIR, 'index.html'))).not_to include('class="ai-tools"')
  end

end
