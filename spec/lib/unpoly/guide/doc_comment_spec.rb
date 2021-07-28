describe Unpoly::Guide::DocComment do

  describe '.find_in_path' do

    it 'finds doc comments in a CoffeeScript file' do
      comments = described_class.find_in_path('spec/fixtures/doc_comment/file.coffee')

      expect(comments.size).to eq(2)

      expect(comments[0].start_line).to eq(3)
      expect(comments[0].end_line).to eq(5)
      expect(comments[0].text).to eq("First doc comment")

      expect(comments[1].start_line).to eq(16)
      expect(comments[1].end_line).to eq(18)
      expect(comments[1].text).to eq("Second, indented doc comment")
    end

    it 'finds doc comments in a JavaScript file' do
      comments = described_class.find_in_path('spec/fixtures/doc_comment/file.js')

      expect(comments.size).to eq(2)

      expect(comments[0].start_line).to eq(3)
      expect(comments[0].end_line).to eq(5)
      expect(comments[0].text).to eq("First doc comment")

      expect(comments[1].start_line).to eq(16)
      expect(comments[1].end_line).to eq(18)
      expect(comments[1].text).to eq("Second, indented doc comment")
    end

    it 'considers a Markdown file as a single doc comment' do
      comments = described_class.find_in_path('spec/fixtures/doc_comment/file.md')

      expect(comments.size).to eq(1)

      expect(comments[0].start_line).to eq(1)
      expect(comments[0].end_line).to eq(2)
      expect(comments[0].text).to eq("Doc comment\nSecond line\n")

    end

  end

end