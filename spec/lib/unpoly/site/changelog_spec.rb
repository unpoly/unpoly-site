describe Unpoly::Site::Changelog do

  subject do
    Unpoly::Site.current.changelog
  end

  describe '#versions' do

    it 'lists the released versions, starting with the current one' do
      expect(subject.versions).to be_present
      expect(subject.versions.first).to eq(Unpoly::Site.current.stable_version)
    end

    it 'lists every version only once' do
      expect(subject.versions.uniq).to eq(subject.versions)
    end

    it 'keeps the order of the changelog, where a maintenance release of an older version may follow a newer release' do
      backport_index = subject.versions.index('1.0.3')

      expect(subject.versions[backport_index - 1]).to eq('2.3.0')
      expect(subject.versions[backport_index + 1]).to eq('2.2.1')
    end

  end

  describe '#release_for_version' do

    it 'finds the release for a version' do
      version = subject.versions.first
      release = subject.release_for_version(version)

      expect(release.version).to eq(version)
      expect(release.markdown).to be_present
    end

    it 'finds a release for every listed version' do
      expect(subject.versions.map { |version| subject.release_for_version(version) }).to all(be_present)
    end

    it 'returns nil for an unreleased version' do
      expect(subject.release_for_version('999.0.0')).to be_nil
    end

  end

  # The site is deployed independently of Unpoly releases, so the changelog often documents
  # a version that has no git tag yet.
  describe 'an unreleased version' do

    def changelog_with(files, tags:)
      dir = Dir.mktmpdir
      (@dirs ||= []) << dir
      FileUtils.mkdir_p(File.join(dir, 'docs', 'changes'))
      files.each { |name, content| File.write(File.join(dir, 'docs', 'changes', name), content) }
      git = "git -C #{Shellwords.escape(dir)} -c user.name=Spec -c user.email=spec@example.com"
      system("#{git} init -q && #{git} add . && #{git} commit -q -m Init", exception: true)
      tags.each { |tag| system("#{git} tag #{tag}", exception: true) }
      described_class.new(dir)
    end

    after do
      @dirs&.each { |dir| FileUtils.rm_rf(dir) }
    end

    let(:changelog) do
      changelog_with({
        'CHANGELOG_3.x.md' => "3.0.0\n-----\n\nThe next major.\n",
        'CHANGELOG_2.x.md' => "2.1.0\n-----\n\nUpcoming.\n\n2.0.0\n-----\n\nReleased.\n\n2.0.0-rc1\n---------\n\nPre-release.\n",
        'CHANGELOG_1.x.md' => "1.0.1\n-----\n\nUpcoming backport.\n\n1.0.0\n-----\n\nReleased.\n",
      }, tags: %w[v2.0.0 v2.0.0-rc1 v1.0.0])
    end

    it 'is left out of the releases, so it gets no page and no listing' do
      expect(changelog.versions).to match_array(%w[2.0.0 2.0.0-rc1 1.0.0])
      expect(changelog.releases_by_version.map(&:version)).to eq(%w[1.0.0 2.0.0-rc1 2.0.0])
      expect(changelog.release_for_version('2.1.0')).to be_nil
      expect(changelog.release_for_version('1.0.1')).to be_nil
    end

    it 'does not count as the current major' do
      expect(changelog.current_major).to eq('2')
    end

    it 'fails when the checkout has no tags, instead of dropping every release' do
      expect { changelog_with({ 'CHANGELOG_1.x.md' => "1.0.0\n-----\n\nReleased.\n" }, tags: []) }.to raise_error(Unpoly::Site::Error, /git fetch --tags/)
    end

    # Unpoly collects the notes for the next release under an "Unreleased" heading at the
    # top of the changelog, until it knows the version number.
    describe 'under an Unreleased heading' do

      let(:changelog) do
        changelog_with({
          'CHANGELOG_2.x.md' => <<~MARKDOWN,
            Unreleased
            ----------

            - Unreleased fix that mentions 2.0.0 in prose.
            - Unreleased fix for a regression in
            2.0.0
            - Unreleased fix with a version number in a [link](/changes/2.0.0).

            ### Forms

            - Unreleased form feature.


            2.0.0
            -----

            Released major.

            ### Forms

            - Released form feature.


            2.0.0-rc1
            ---------

            Pre-release.
          MARKDOWN
          'CHANGELOG_1.x.md' => "1.0.0\n-----\n\nReleased.\n",
        }, tags: %w[v2.0.0 v2.0.0-rc1 v1.0.0])
      end

      it 'creates no release' do
        expect(changelog.versions).to match_array(%w[2.0.0 2.0.0-rc1 1.0.0])
        expect(changelog.release_for_version('Unreleased')).to be_nil
      end

      it 'leaves the first tagged version as the newest release' do
        expect(changelog.releases.first.version).to eq('2.0.0')
        expect(changelog.current_major).to eq('2')
      end

      it 'leaks none of its entries into a release' do
        expect(changelog.release_for_version('2.0.0').markdown).to eq("Released major.\n\n### Forms\n\n- Released form feature.")
        changelog.releases.each do |release|
          expect(release.markdown).not_to include('Unreleased')
        end
      end

    end

  end

  describe 'a release' do

    let(:release) { subject.releases.first }

    it 'knows its git tag' do
      expect(release.git_tag).to eq("v#{release.version}")
    end

    it 'links to its commits on GitHub' do
      expect(release.github_browse_url).to include(release.git_tag)
    end

    it 'belongs to the current major version' do
      expect(release).to be_current_major
    end

    describe '#previous_release_by_version' do

      it 'is the next lower version, so the site can show a diff' do
        expect(release.previous_release_by_version.version).to eq(subject.versions.second)
      end

      # E.g. 1.0.3 was released after 2.2.1, but its changes are relative to 1.0.1.
      it 'is the next lower version of the same line for a maintenance release of an older version' do
        backport = subject.release_for_version('1.0.3')

        expect(backport.previous_release_by_version.version).to eq('1.0.1')
        expect(backport).not_to be_current_major
      end

    end

  end

end
