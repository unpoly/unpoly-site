describe Unpoly::Guide::DynamicTokens do

  let(:repository) do
    instance_double(
      Unpoly::Guide::Repository,
      version: '3.11.0',
      pre_release?: false,
      library_size: '12.3 KB',
    )
  end

  def substitute(text, source: nil)
    described_class.substitute(text, repository: repository, source: source)
  end

  describe 'known tokens' do

    it 'replaces [[=version]] with the version we are building' do
      expect(substitute('Get unpoly@[[=version]] now.')).to eq('Get unpoly@3.11.0 now.')
    end

    it 'replaces [[=npm_tag]] with nothing on a stable version' do
      expect(substitute('npm install unpoly[[=npm_tag]]')).to eq('npm install unpoly')
    end

    it 'replaces [[=npm_tag]] with @next on a pre-release' do
      allow(repository).to receive(:pre_release?).and_return(true)

      expect(substitute('npm install unpoly[[=npm_tag]]')).to eq('npm install unpoly@next')
    end

    it 'passes an argument to [[=size FILE]]' do
      expect(repository).to receive(:library_size).with('unpoly.min.js').and_return('12.3 KB')

      expect(substitute('Weighs [[=size unpoly.min.js]] gzipped.')).to eq('Weighs 12.3 KB gzipped.')
    end

    it 'parses a quoted argument containing spaces' do
      expect(repository).to receive(:library_size).with('a file.js').and_return('1 KB')

      expect(substitute('[[=size "a file.js"]]')).to eq('1 KB')
    end

    it 'substitutes inside code blocks, where no template helper could reach' do
      markdown = "```\nnpm install unpoly@[[=version]]\n```\n"

      expect(substitute(markdown)).to eq("```\nnpm install unpoly@3.11.0\n```\n")
    end

  end

  describe 'escaping' do

    it 'renders a literal token when escaped with a backslash' do
      expect(substitute('Write \\[[=version]] to interpolate.')).to eq('Write [[=version]] to interpolate.')
    end

  end

  describe 'failing the build' do

    it 'rejects an unknown token, listing the known tokens' do
      expect { substitute('See [[=nope]].') }
        .to raise_error(described_class::Malformed, /Unknown dynamic token \[\[=nope\]\].*Known tokens:.*\[\[=version\]\].*\[\[=npm_tag\]\].*\[\[=size FILE\]\]/)
    end

    it 'rejects a malformed token' do
      expect { substitute('See [[=]].') }.to raise_error(described_class::Malformed, /Malformed dynamic token/)
    end

    it 'rejects an unclosed token' do
      expect { substitute('See [[=version.') }.to raise_error(described_class::Malformed, /Unclosed dynamic token/)
    end

    it 'rejects a wrong number of arguments, naming the signature' do
      expect { substitute('See [[=version 3]].') }
        .to raise_error(described_class::Malformed, /takes 0 argument\(s\), got 1/)

      expect { substitute('See [[=size]].') }
        .to raise_error(described_class::Malformed, /takes 1 argument\(s\), got 0.*\[\[=size FILE\]\]/)
    end

    it 'names the source of a bad token' do
      expect { substitute('See [[=nope]].', source: 'src/unpoly/link.js:12') }
        .to raise_error(described_class::Malformed, %r{src/unpoly/link\.js:12})
    end

  end

end
