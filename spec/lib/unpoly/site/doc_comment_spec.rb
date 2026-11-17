describe Unpoly::Site::DocComment do

  describe '.find_in_path' do

    it 'finds doc comments in a CoffeeScript file' do
      comments = described_class.find_in_path('spec/fixtures/doc_comment/file.coffee', root: 'spec/fixtures/doc_comment')

      expect(comments.size).to eq(2)

      expect(comments[0].start_line).to eq(3)
      expect(comments[0].end_line).to eq(5)
      expect(comments[0].text).to eq("First doc comment")

      expect(comments[1].start_line).to eq(16)
      expect(comments[1].end_line).to eq(18)
      expect(comments[1].text).to eq("Second, indented doc comment")
    end

    it 'finds doc comments in a JavaScript file' do
      comments = described_class.find_in_path('spec/fixtures/doc_comment/file.js', root: 'spec/fixtures/doc_comment')

      expect(comments.size).to eq(2)

      expect(comments[0].start_line).to eq(3)
      expect(comments[0].end_line).to eq(5)
      expect(comments[0].text).to eq("First doc comment")

      expect(comments[1].start_line).to eq(16)
      expect(comments[1].end_line).to eq(18)
      expect(comments[1].text).to eq("Second, indented doc comment")
    end

    it 'finds doc comments in a TypeScript file' do
      comments = described_class.find_in_path('spec/fixtures/doc_comment/file.ts', root: 'spec/fixtures/doc_comment')

      expect(comments.size).to eq(2)

      expect(comments[0].start_line).to eq(3)
      expect(comments[0].end_line).to eq(5)
      expect(comments[0].text).to eq("First doc comment")

      expect(comments[1].start_line).to eq(16)
      expect(comments[1].end_line).to eq(18)
      expect(comments[1].text).to eq("Second, indented doc comment")
    end

    it 'considers a Markdown file in a pages directory as a single doc comment' do
      comments = described_class.find_in_path('spec/fixtures/doc_comment/pages/file.md', root: 'spec/fixtures/doc_comment')

      expect(comments.size).to eq(1)

      expect(comments[0].start_line).to eq(1)
      expect(comments[0].end_line).to eq(2)
      expect(comments[0].text).to eq("Doc comment\nSecond line\n")
    end

    it 'only considers a pages directory below the root, not one above it' do
      Dir.mktmpdir do |dir|
        root = File.join(dir, 'pages', 'unpoly', 'src')
        FileUtils.mkdir_p(File.join(root, 'pages'))
        markdown = "# test.one()\n\n-----\n\n# test.two()\n"
        File.write(File.join(root, 'doc.md'), markdown)
        File.write(File.join(root, 'pages', 'guide.md'), markdown)

        expect(described_class.find_in_path(File.join(root, 'doc.md'), root: root).size).to eq(2)
        expect(described_class.find_in_path(File.join(root, 'pages', 'guide.md'), root: root).size).to eq(1)
      end
    end

    describe 'a Markdown doc file beside a source file' do

      def find_in_doc_file(markdown)
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'file.md')
          File.write(path, markdown)
          described_class.find_in_path(path, root: dir)
        end
      end

      it 'splits entries at a line of five or more dashes, with a blank line above and below' do
        comments = find_in_doc_file(<<~MARKDOWN)
          # test.one()

          First entry
          @function test.one

          -----

          # test.two()

          Second entry
          @function test.two

          ----------

          # test.three()

          Third entry
          @function test.three
        MARKDOWN

        expect(comments.map(&:heading)).to eq(['test.one()', 'test.two()', 'test.three()'])
        expect(comments.map(&:text)).to eq([
          "First entry\n@function test.one\n",
          "Second entry\n@function test.two\n",
          "Third entry\n@function test.three\n",
        ])
      end

      it 'splits entries in a file with CRLF line endings' do
        comments = find_in_doc_file("# test.one()\r\n\r\nFirst entry\r\n\r\n-----\r\n\r\n# test.two()\r\n\r\nSecond entry\r\n")

        expect(comments.map(&:heading)).to eq(['test.one()', 'test.two()'])
        expect(comments.map(&:text)).to eq(["First entry\n", "Second entry\n"])
      end

      it 'splits entries at a separator with trailing whitespace, between lines that hold only whitespace' do
        comments = find_in_doc_file("# test.one()\n\nFirst entry\n  \n----- \t\n\t\n# test.two()\n")

        expect(comments.map(&:heading)).to eq(['test.one()', 'test.two()'])
      end

      it 'keeps the bodies of @params when the blank line after the H1 holds spaces' do
        comments = find_in_doc_file("# test.one()\n  \nProse\n@param foo\n  Desc\n")

        expect(comments[0].text).to eq("Prose\n@param foo\n  Desc\n")
      end

      it "points an entry's lines from its H1 to its last line" do
        comments = find_in_doc_file("# test.one()\n\nFirst entry\n\n-----\n\n# test.two()\n\nSecond entry\nLast line\n")

        expect([comments[0].start_line, comments[0].end_line]).to eq([1, 3])
        expect([comments[1].start_line, comments[1].end_line]).to eq([7, 10])
        expect(comments[1].path_with_lines).to end_with('file.md:7:10')
      end

      it 'keeps a thematic break of three or four dashes in the entry' do
        comments = find_in_doc_file("# test.one()\n\nBefore\n\n---\n\n----\n\nAfter\n")

        expect(comments.size).to eq(1)
        expect(comments[0].text).to eq("Before\n\n---\n\n----\n\nAfter\n")
      end

      it 'keeps a line of dashes without a blank line above or below in the entry' do
        comments = find_in_doc_file("# test.one()\n\nSetext heading\n--------------\n\nBefore\n\n-----\nAfter\n")

        expect(comments.size).to eq(1)
        expect(comments[0].text).to include("--------------")
        expect(comments[0].text).to include("-----\nAfter")
      end

      it 'keeps an indented line of dashes in the entry' do
        comments = find_in_doc_file("# test.one()\n\nBefore\n\n  -----\n\nAfter\n")

        expect(comments.size).to eq(1)
      end

      it 'keeps lines of dashes and H1s in code blocks in the entry, also when the fence is indented' do
        comments = find_in_doc_file(<<~MARKDOWN)
          # test.one()

          ```text

          -----

          # Not a heading
          ```

          @param foo
            ~~~~
            ```

            -----

            ~~~~

          -----

          # test.two()
        MARKDOWN

        expect(comments.map(&:heading)).to eq(['test.one()', 'test.two()'])
        expect(comments[0].text).to include("# Not a heading")
      end

      it 'keeps lines of dashes and H1s in a ~~~ fence or a longer backtick fence, which a ``` does not close' do
        comments = find_in_doc_file(<<~MARKDOWN)
          # test.one()

          ~~~
          ```

          -----

          # Not a heading
          ~~~

          ````md
          ```

          -----

          # Not a heading
          ```
          ````

          ```

          -----

          # Not a heading
          `````

          -----

          # test.two()
        MARKDOWN

        expect(comments.map(&:heading)).to eq(['test.one()', 'test.two()'])
      end

      it 'finds a fence that opens a list item, so that its closing fence does not open another one' do
        comments = find_in_doc_file(<<~MARKDOWN)
          # test.one()

          1. ```js
             up.render()
             ```
          - ~~~
            up.render()
            ~~~

          -----

          # test.two()
        MARKDOWN

        expect(comments.map(&:heading)).to eq(['test.one()', 'test.two()'])
      end

      it 'removes a closing sequence of #s from the H1' do
        comments = find_in_doc_file("# test.one() ##\n\n-----\n\n# test.Class#method()\n")

        expect(comments.map(&:heading)).to eq(['test.one()', 'test.Class#method()'])
      end

      it 'removes backslash escapes from the H1' do
        comments = find_in_doc_file("# \\[test-one]\n\n-----\n\n# \\_test_two\n")

        expect(comments.map(&:heading)).to eq(['[test-one]', '_test_two'])
      end

      it 'ignores a byte order mark before the first H1' do
        comments = find_in_doc_file("\uFEFF# test.one()\n\nFirst entry\n")

        expect(comments.map(&:heading)).to eq(['test.one()'])
      end

      it 'fails on a separator before the first entry' do
        expect { find_in_doc_file("-----\n\n# test.one()\n") }.to raise_error(Unpoly::Site::Parser::CannotParse, /Empty entry.*file\.md:1/)
      end

      it 'fails on a separator after the last entry' do
        expect { find_in_doc_file("# test.one()\n\n-----\n") }.to raise_error(Unpoly::Site::Parser::CannotParse, /Empty entry.*file\.md:3/)
      end

      it 'fails on a separator after the last entry, also without a trailing line feed' do
        expect { find_in_doc_file("# test.one()\n\n-----") }.to raise_error(Unpoly::Site::Parser::CannotParse, /Empty entry.*file\.md:3/)
      end

      it 'fails on an entry that does not start with an H1' do
        expect { find_in_doc_file("# test.one()\n\n-----\n\n## test.two()\n") }.to raise_error(Unpoly::Site::Parser::CannotParse, /must start with an H1.*file\.md:5/)
      end

      it 'fails on a second H1 in an entry, which hints at a missing separator' do
        expect { find_in_doc_file("# test.one()\n\n---\n\n# test.two()\n") }.to raise_error(Unpoly::Site::Parser::CannotParse, /second H1.*file\.md:5/)
      end

      it 'fails on a code block that is never closed' do
        expect { find_in_doc_file("# test.one()\n\n```js\n\n-----\n\n# test.two()\n") }.to raise_error(Unpoly::Site::Parser::CannotParse, /Unclosed code fence.*file\.md:3/)
      end

      it 'fails on a fence marker in an indented code block, naming that as a cause' do
        expect { find_in_doc_file("# test.one()\n\n    ```\n\n-----\n\n# test.two()\n") }.to raise_error(Unpoly::Site::Parser::CannotParse, /Unclosed code fence \(a fence marker in an indented code block opens one too\): .*file\.md:3/)
      end

      it 'finds no entries in an empty file' do
        expect(find_in_doc_file("\n")).to eq([])
      end

    end

  end

end