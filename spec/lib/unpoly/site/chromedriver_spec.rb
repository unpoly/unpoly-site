require 'tmpdir'

describe Unpoly::Site::Chromedriver do

  # A home and a PATH with fake executables that print a version, as the real ones do.
  around do |example|
    Dir.mktmpdir do |dir|
      @home = File.join(dir, 'home')
      @path_dir = File.join(dir, 'path')
      FileUtils.mkdir_p([File.join(@home, 'bin'), @path_dir])
      memo = described_class.instance_variable_get(:@path)
      described_class.instance_variable_set(:@path, nil)
      old_env = ENV.to_h.slice('HOME', 'PATH')
      ENV.update('HOME' => @home, 'PATH' => @path_dir)
      example.run
    ensure
      ENV.update(old_env)
      described_class.instance_variable_set(:@path, memo)
    end
  end

  def executable(file, version_line)
    File.write(file, "#!/bin/sh\necho '#{version_line}'\n")
    File.chmod(0o755, file)
    file
  end

  def chrome(version)
    executable(File.join(@path_dir, 'google-chrome'), "Google Chrome #{version}")
  end

  def driver(dir, version)
    executable(File.join(dir, 'chromedriver'), "ChromeDriver #{version} (5869fe31-refs/branch-heads/8059@{#1303})")
  end

  describe '.path' do
    it 'takes the chromedriver in ~/bin over the one on the PATH' do
      chrome('155.0.8059.84')
      driver(@path_dir, '155.0.8059.84')
      in_home = driver(File.join(@home, 'bin'), '155.0.8059.84')
      expect(described_class.path).to eq(in_home)
    end

    it 'takes the chromedriver on the PATH without one in ~/bin' do
      chrome('155.0.8059.84')
      on_path = driver(@path_dir, '155.0.8059.84')
      expect(described_class.path).to eq(on_path)
    end

    it 'fails without a chromedriver, and says what to install' do
      chrome('155.0.8059.84')
      expect { described_class.path }.to raise_error(described_class::Error) { |error|
        expect(error.message).to include('Found no chromedriver in ~/bin or on the PATH, for Chrome 155', '~/bin', 'SKIP_OG_IMAGES=1')
      }
    end

    it "fails with a chromedriver for another Chrome, and does not fall back to the next one" do
      chrome('155.0.8059.84')
      driver(@path_dir, '155.0.8059.84')
      stale = driver(File.join(@home, 'bin'), '86.0.4240.22')
      expect { described_class.path }.to raise_error(described_class::Error, /Found #{Regexp.escape(stale)} for Chrome 86, but Chrome 155 is installed/)
    end

    it 'fails without Chrome' do
      driver(@path_dir, '155.0.8059.84')
      expect { described_class.path }.to raise_error(described_class::Error, /Found no Chrome/)
    end
  end

end
