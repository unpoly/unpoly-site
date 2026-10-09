require 'digest'
require 'json'
require 'yaml'
require 'zlib'
require 'rubygems/package'

module Unpoly
  module Guide
    # Checks the skill that Middleman built into build/skills/unpoly-docs/, then packs it
    # for its two install routes (an after_build step in config.rb):
    #
    #   npx skills add https://unpoly.com
    #     /.well-known/agent-skills/index.json + unpoly-docs.tar.gz (SKILL.md at the root)
    #
    #   /plugin marketplace add https://unpoly.com/claude-plugins/marketplace.json
    #   /plugin install unpoly@unpoly
    #     /claude-plugins/marketplace.json + unpoly.zip (skill at skills/unpoly-docs/)
    #
    # A third archive is for people to download and upload to a chat with skill support
    # (claude.ai, chatgpt.com): /agent-skills/unpoly-docs.zip, the skill folder at its root.
    #
    # The indexes embed digests of the archives, which is why these files are written
    # after the build rather than rendered as pages. Name and description come from
    # SKILL.md's front matter, so they are written once.
    #
    # The well-known files are written to build/agent-skills/: the deploy archives the
    # build without dot-directories, so .htaccess maps /.well-known/agent-skills/ there.
    class SkillPackage
      class Invalid < Error; end

      MAX_FILES = 1000 # `npx skills` refuses bigger archives
      MAX_DESCRIPTION = 200 # claude.ai refuses a skill with a longer description
      MARKETPLACE = 'unpoly'
      PLUGIN = 'unpoly'

      FRONT_MATTER = /\A---\n(.*?)\n---\n/m

      def initialize(build_dir:, stamp:)
        @build_dir = build_dir
        @stamp = stamp
      end

      def skill_dir
        File.join(@build_dir, Skill::ROOT)
      end

      # Relative paths of the skill's files, sorted.
      def files
        @files ||= Dir.glob('**/*', File::FNM_DOTMATCH, base: skill_dir)
          .select { |file| File.file?(File.join(skill_dir, file)) }
          .sort
      end

      def problems
        problems = []
        problems << "#{files.size} files, but archives may hold at most #{MAX_FILES - 1}" if files.size >= MAX_FILES
        problems += description_problems + filename_problems + front_matter_problems + link_problems
        problems
      end

      def check!
        problems = self.problems
        return if problems.empty?

        raise Invalid, "The skill in #{skill_dir} is broken:\n  #{problems.first(50).join("\n  ")}"
      end

      def package!
        check!
        skill = skill_front_matter

        tarball = write('agent-skills/unpoly-docs.tar.gz', tar_gz)
        write('agent-skills/index.json', JSON.pretty_generate(
          '$schema' => 'https://schemas.agentskills.io/discovery/0.2.0/schema.json',
          'skills' => [{
            'name' => skill.fetch('name'),
            'type' => 'archive',
            'description' => skill.fetch('description'),
            'url' => "/.well-known/agent-skills/#{Skill::NAME}.tar.gz",
            'digest' => "sha256:#{Digest::SHA256.hexdigest(tarball)}",
          }],
        ) + "\n")

        write("agent-skills/#{Skill::NAME}.zip", zip_archive("#{Skill::NAME}/"))

        zip = write("claude-plugins/#{PLUGIN}.zip", zip_archive("skills/#{Skill::NAME}/"))
        write('claude-plugins/marketplace.json', JSON.pretty_generate(
          'name' => MARKETPLACE,
          'owner' => { 'name' => 'Unpoly' },
          'description' => 'Plugins for working with Unpoly.',
          'plugins' => [{
            'name' => PLUGIN,
            'description' => skill.fetch('description'),
            # Claude Code only updates a plugin whose version changed.
            'version' => @stamp,
            'source' => {
              'source' => 'archive',
              'url' => "#{Guide.base_url}/claude-plugins/#{PLUGIN}.zip",
              'sha256' => Digest::SHA256.hexdigest(zip),
            },
          }],
        ) + "\n")
      end

      private

      def skill_front_matter
        front_matter = read('SKILL.md')[FRONT_MATTER, 1] or raise Invalid, 'SKILL.md has no front matter'
        YAML.safe_load(front_matter)
      end

      def description_problems
        description = skill_front_matter['description'].to_s
        return [] if description.length <= MAX_DESCRIPTION

        ["SKILL.md: the description has #{description.length} characters, but claude.ai accepts at most #{MAX_DESCRIPTION}"]
      end

      def write(path, content)
        full_path = File.join(@build_dir, path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.binwrite(full_path, content)
        content
      end

      # ---------- Checks ----------

      def filename_problems
        problems = []
        files.group_by(&:downcase).each_value do |group|
          problems << "file names differ only in case: #{group.join(', ')}" if group.size > 1
        end
        files.each do |file|
          problems << "#{file}: ':' and '$' break file systems and shells" if file =~ /[:$]/
          problems << "#{file}: a test file must stay out of the skill" if File.basename(file).start_with?('test_')
        end
        problems
      end

      # The search script only reads flat `key: "value"` lines.
      def front_matter_problems
        markdown_files.filter_map do |file|
          next if file == 'SKILL.md'

          text = read(file)
          front_matter = text[FRONT_MATTER, 1]
          next "#{file}: no front matter" unless front_matter

          bad = front_matter.lines.map(&:chomp).reject { |line| flat_front_matter_line?(line) }
          "#{file}: front matter is not flat (#{bad.first})" if bad.any?
        end
      end

      def flat_front_matter_line?(line)
        line =~ /\A[a-z_]+: (".*")\z/ && JSON.parse($1).is_a?(String)
      rescue JSON::ParserError
        false
      end

      # Every relative link must reach a file of the skill, which installs without the
      # site.
      def link_problems
        markdown_files.flat_map do |file|
          text = read(file).gsub(/^(```+|~~~+).*?^\1/m, '').gsub(/`+[^`\n]*`+/, '')
          text.scan(/\]\(([^)\s]+)\)/).flatten.filter_map do |href|
            next if href =~ /\A([a-z][a-z0-9+.-]*:|#)/i

            target = File.expand_path(href.split('#').first, File.join('/', File.dirname(file)))
            "#{file}: broken link to #{href}" unless File.file?(File.join(skill_dir, target))
          end
        end
      end

      def markdown_files
        files.select { |file| file.end_with?('.md') }
      end

      def read(file)
        File.read(File.join(skill_dir, file))
      end

      # ---------- Archives ----------

      def tar_gz
        io = StringIO.new
        gzip = Zlib::GzipWriter.new(io)
        Gem::Package::TarWriter.new(gzip) do |tar|
          files.each do |file|
            content = File.binread(File.join(skill_dir, file))
            mode = File.executable?(File.join(skill_dir, file)) ? 0o755 : 0o644
            tar.add_file_simple(file, mode, content.bytesize) { |entry| entry.write(content) }
          end
        end
        gzip.close
        io.string
      end

      def zip_archive(prefix)
        entries = files.map { |file| ["#{prefix}#{file}", File.binread(File.join(skill_dir, file))] }
        Zip.write(entries)
      end

      # Just enough of the ZIP format for one archive of small files: deflated entries,
      # no ZIP64, no extra fields. Ruby has no ZIP writer of its own.
      module Zip
        module_function

        def write(entries)
          time = Time.now
          dos_time = (time.hour << 11) | (time.min << 5) | (time.sec / 2)
          dos_date = ((time.year - 1980) << 9) | (time.month << 5) | time.day
          out = ''.b
          central = ''.b

          entries.each do |name, content|
            name = name.b
            data = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS).then { |z| z.deflate(content, Zlib::FINISH).tap { z.close } }
            crc = Zlib.crc32(content)
            offset = out.bytesize
            # version needed, flags (bit 11: UTF-8 names), method 8 (deflate), time, date,
            # crc, compressed and uncompressed size, name length, extra length
            header = [20, 0x0800, 8, dos_time, dos_date, crc, data.bytesize, content.bytesize, name.bytesize, 0]
            out << [0x04034b50, *header].pack('VvvvvvVVVvv') << name << data
            # Made by Unix (3 << 8), so the external attributes carry a file mode.
            central << [0x02014b50, (3 << 8) | 20, *header, 0, 0, 0, 0o100644 << 16, offset].pack('VvvvvvvVVVvvvvvVV') << name
          end

          out << central
          out << [0x06054b50, 0, 0, entries.size, entries.size, central.bytesize, out.bytesize - central.bytesize, 0].pack('VvvvvVVv')
        end
      end
    end
  end
end
