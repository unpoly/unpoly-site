describe Unpoly::Guide::Changelog do

  subject do
    Unpoly::Guide.current.changelog
  end

  describe '#versions' do

    it 'lists the released versions, starting with the current one' do
      expect(subject.versions).to be_present
      expect(subject.versions.first).to eq(Unpoly::Guide.current.stable_version)
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
