require 'open3'

# The skill's search script (source/skills/unpoly-docs/scripts/search.py) is Python and
# has Python tests next to it. They run here so that `bundle exec rspec` (and CI) covers
# them too; `rake skill:test` runs them on their own.
#
# - test_search.py: unit tests on a corpus of their own. Need python3.
# - test_ranking.py: a fixed set of queries with the page each must find, against the
#   skill of the last build. Skipped without one. `rake skill:test` builds the skill
#   first, which is how CI runs it.
describe 'the skill search script' do

  SCRIPTS_DIR = File.expand_path('../../source/skills/unpoly-docs/scripts', __dir__)
  BUILT_SKILL = File.expand_path('../../build/skills/unpoly-docs', __dir__)

  before do
    skip 'python3 is not installed' unless system('python3 --version', out: File::NULL, err: File::NULL)
  end

  def unittest(mod, env = {})
    output, status = Open3.capture2e(env, 'python3', '-m', 'unittest', mod, chdir: SCRIPTS_DIR)
    expect(status).to be_success, output
    output
  end

  it 'passes its unit tests' do
    unittest('test_search')
  end

  it 'ranks the expected pages first for the fixed queries' do
    skip 'no build/skills/unpoly-docs (run `bundle exec middleman build`)' unless File.directory?(File.join(BUILT_SKILL, 'references'))
    output = unittest('test_ranking', 'UNPOLY_SKILL_DIR' => BUILT_SKILL)
    expect(output).not_to include('skipped')
  end

end
