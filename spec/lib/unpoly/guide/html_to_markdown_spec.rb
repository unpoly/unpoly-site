describe Unpoly::Guide::HtmlToMarkdown do

  let(:links) do
    Unpoly::Guide::MarkdownLinks::Web.new(
      base_url: 'https://unpoly.com',
      twin_paths: Set['/up.render', '/up.link', '/targeting-fragments'],
      page_path: '/up.link'
    )
  end

  def convert(html)
    described_class.new(links: links).convert(html)
  end

  describe 'text' do
    it 'turns paragraphs into blocks separated by blank lines' do
      expect(convert('<p>One  two</p><p>Three</p>')).to eq("One two\n\nThree\n")
    end

    it 'makes a paragraph of inline content between blocks' do
      expect(convert("<div>Loose <b>text</b><p>Para</p>more</div>")).to eq("Loose **text**\n\nPara\n\nmore\n")
    end

    it 'converts emphasis, strong and code spans' do
      expect(convert('<p><em>a</em> <strong>b</strong> <code>up.render()</code> <kbd>/</kbd></p>')).to eq("_a_ **b** `up.render()` `/`\n")
    end

    it 'fences a code span that contains a backtick' do
      expect(convert('<p><code>a`b</code></p>')).to eq("``a`b``\n")
    end

    it 'treats a block element inside a heading as a word boundary' do
      expect(convert('<h2>Title<div>Sub</div></h2>')).to eq("## Title Sub\n")
    end
  end

  describe 'headings' do
    it 'converts h1-h6 with their level' do
      expect(convert('<h1>A</h1><h3>B</h3>')).to eq("# A\n\n### B\n")
    end

    it 'converts [role=heading] with its aria-level' do
      expect(convert('<div role="heading" aria-level="4">Param</div>')).to eq("#### Param\n")
    end

    it "appends the heading's id Kramdown style" do
      expect(convert('<h2 id="usage">Usage</h2>')).to eq("## Usage {#usage}\n")
    end

    it 'takes the id of an [anchor-link] block the heading sits in' do
      html = <<~HTML
        <div class="feature--param" id="options.target" anchor-link>
          <div role="heading" aria-level="3">[options.target]</div>
          <p>The target.</p>
        </div>
      HTML
      expect(convert(html)).to eq("### [options.target] {#options.target}\n\nThe target.\n")
    end

    it 'does not give the id of an [anchor-link] block to a second heading' do
      html = '<div id="x" anchor-link><h3>One</h3><h4>Two</h4></div>'
      expect(convert(html)).to eq("### One {#x}\n\n#### Two\n")
    end

    it 'skips an empty heading' do
      expect(convert('<h2 id="x"><span aria-hidden="true">#</span></h2><p>Text</p>')).to eq("Text\n")
    end
  end

  describe 'links' do
    it "uses a link's aria-label as its text" do
      expect(convert('<p><a href="/up.render" aria-label="Previous: Rendering">Previous</a></p>')).to eq("[Previous: Rendering](https://unpoly.com/up.render.md)\n")
    end

    it 'keeps a link without href as text' do
      expect(convert('<p><a>Plain</a></p>')).to eq("Plain\n")
    end

    it 'drops a link without text' do
      expect(convert('<p>A<a href="/up.render"><i class="fa fa-x" aria-hidden="true"></i></a>B</p>')).to eq("AB\n")
    end

    it 'runs the blocks of a link that wraps blocks into its text' do
      expect(convert('<a href="/up.render"><div>One</div><div>Two</div></a>')).to eq("[One Two](https://unpoly.com/up.render.md)\n")
    end

    it 'renders the blocks of an unknown inline element that wraps blocks' do
      expect(convert('<span><div>One</div><div>Two</div></span>')).to eq("One\n\nTwo\n")
    end
  end

  describe 'dropping' do
    it 'drops [data-markdown=ignore], [aria-hidden], [hidden] and non-content elements with their contents' do
      html = <<~HTML
        <p>Kept</p>
        <a class="edit-link" data-markdown="ignore">Edit <b>page</b></a>
        <span aria-hidden="true">Decoration</span>
        <div hidden>Hidden</div>
        <script>alert(1)</script><style>p {}</style><template><p>T</p></template><noscript>N</noscript>
      HTML
      expect(convert(html)).to eq("Kept\n")
    end

    it 'drops an svg that is no image' do
      expect(convert('<p>A <svg><text>gibberish</text></svg>B</p>')).to eq("A B\n")
    end
  end

  describe 'chips' do
    it "writes a chip's title in parentheses" do
      html = '<h1>up.render() <span data-markdown="chip" title="JavaScript function">JS</span></h1>'
      expect(convert(html)).to eq("# up.render() (JavaScript function)\n")
    end

    it "writes a chip's text when it has no title" do
      expect(convert('<p><span class="tag" data-markdown="chip"> optional </span></p>')).to eq("(optional)\n")
    end

    it 'writes a labelled SVG icon as its label, and drops an unlabelled one' do
      html = %(<p>A #{Unpoly::Guide::Icon.html('markdown', label: 'Markdown')} B #{Unpoly::Guide::Icon.html('markdown')}</p>)
      expect(convert(html)).to eq("A (Markdown) B\n")
    end

    it 'writes a labelled icon as its label' do
      html = '<p>Flag <i class="fa fa-flask" role="img" aria-label="Experimental"></i></p>'
      expect(convert(html)).to eq("Flag (Experimental)\n")
    end
  end

  describe 'navs' do
    it 'keeps a nav as a literal <nav> block with its links as a bullet list' do
      html = '<nav aria-label="Guides"><a href="/targeting-fragments">Learn: Targeting</a> <a href="https://example.com">Out</a></nav>'
      expect(convert(html)).to eq(<<~MARKDOWN)
        <nav aria-label="Guides">

        - [Learn: Targeting](https://unpoly.com/targeting-fragments.md)
        - [Out](https://example.com)

        </nav>
      MARKDOWN
    end

    it 'keeps headings in a nav and takes the label from aria-labelledby' do
      html = '<nav aria-labelledby="t"><h2 id="t">In this chapter</h2><a href="/up.link">Linking</a></nav>'
      expect(convert(html)).to eq(<<~MARKDOWN)
        <nav aria-label="In this chapter">

        ## In this chapter {#t}

        - [Linking](https://unpoly.com/up.link.md)

        </nav>
      MARKDOWN
    end

    it 'treats [role=navigation] as a nav' do
      expect(convert('<div role="navigation"><a href="#a">A</a></div>')).to eq("<nav>\n\n- [A](#a)\n\n</nav>\n")
    end
  end

  describe 'code blocks' do
    it 'fences a block with the language of its highlighting class' do
      html = %(<pre><code class="language-html">&lt;a up-follow&gt;\n</code></pre>)
      expect(convert(html)).to eq("```html\n<a up-follow>\n```\n")
    end

    it 'removes mark comments' do
      html = <<~HTML
        <pre><code class="language-js">up.render('.a') // mark: '.a'
        let x = 1 // mark-line
        &lt;a up-follow&gt;A&lt;/a&gt; &lt;!-- mark: up-follow --&gt;
        # mark-line
        </code></pre>
      HTML
      expect(convert(html)).to eq("```js\nup.render('.a')\nlet x = 1\n<a up-follow>A</a>\n```\n")
    end

    it 'keeps the text of chip and label comments, and result comments as they are' do
      html = <<~HTML
        <pre><code>// label: Example
        &lt;b&gt;&lt;/b&gt; &lt;!-- chip: compiles --&gt;
        up.render() // result: up.RenderJob
        </code></pre>
      HTML
      expect(convert(html)).to eq("```\n// Example\n<b></b> <!-- compiles -->\nup.render() // result: up.RenderJob\n```\n")
    end

    it 'uses a longer fence when the code contains one' do
      expect(convert("<pre><code>```\nx\n```</code></pre>")).to eq("````\n```\nx\n```\n````\n")
    end
  end

  describe 'lists' do
    it 'converts nested lists, keeping short items tight' do
      html = '<ul><li>One<ul><li>Nested</li></ul></li><li>Two</li></ul><ol start="3"><li>Three</li><li>Four</li></ol>'
      expect(convert(html)).to eq("- One\n  - Nested\n- Two\n\n3. Three\n4. Four\n")
    end

    it 'makes a loose list when an item has several blocks' do
      html = '<ul><li><h4>Title</h4><p>Text</p></li><li><p>Other</p></li></ul>'
      expect(convert(html)).to eq("- #### Title\n\n  Text\n\n- Other\n")
    end
  end

  describe 'tables' do
    it 'converts a table to GFM, escaping pipes and padding short rows' do
      html = <<~HTML
        <table>
          <thead><tr><th>Name</th><th>Type</th></tr></thead>
          <tbody><tr><td><code>a</code></td><td>string | Element</td></tr><tr><td>b</td></tr></tbody>
        </table>
      HTML
      expect(convert(html)).to eq("| Name | Type |\n| --- | --- |\n| `a` | string \\| Element |\n| b |  |\n")
    end
  end

  describe 'blockquotes' do
    it 'quotes the blocks of a blockquote (an admonition keeps its title as a heading)' do
      html = '<blockquote class="admonition -tip"><h4 class="admonition--title"><i class="fa fa-x" aria-hidden="true"></i>Tip</h4><p>Do it.</p></blockquote>'
      expect(convert(html)).to eq("> #### Tip\n>\n> Do it.\n")
    end
  end

  describe 'media' do
    it 'links an image on the site with its alt text' do
      expect(convert('<p><img src="/images/api/a.png" alt="A screenshot"></p>')).to eq("![A screenshot](https://unpoly.com/images/api/a.png)\n")
    end

    it 'fails on an image without alt text' do
      expect { convert('<img src="/a.png" alt="">') }.to raise_error(described_class::Error, /alt/)
      expect { convert('<img src="/a.png">') }.to raise_error(described_class::Error, /alt/)
    end

    it 'links a video by its description' do
      expect(convert('<video src="/images/api/a.webm" aria-label="A demo"></video>')).to eq("[Video: A demo](https://unpoly.com/images/api/a.webm)\n")
      expect(convert('<figure><video><source src="/v.mp4"></video><figcaption>Caption</figcaption></figure>')).to start_with("[Video: Caption](https://unpoly.com/v.mp4)")
    end

    it 'fails on a video without a description' do
      expect { convert('<video src="/a.webm"></video>') }.to raise_error(described_class::Error, /description/)
    end

    it 'links a diagram on the HTML page by its title, followed by its description' do
      html = <<~HTML
        <figure id="fragment-updates-diagram">
          <svg role="img"><title>How it works</title><desc>Three requests.</desc><text>noise</text></svg>
        </figure>
      HTML
      expect(convert(html)).to eq("[Diagram: How it works](https://unpoly.com/up.link#fragment-updates-diagram)\n\nThree requests.\n")
    end

    it 'fails on a diagram without a name or without an id' do
      expect { convert('<figure id="d"><svg role="img"></svg></figure>') }.to raise_error(described_class::Error, /name/)
      expect { convert('<svg role="img" aria-label="D"></svg>') }.to raise_error(described_class::Error, /id/)
    end
  end

  it 'separates sections with a rule' do
    expect(convert('<p>A</p><hr class="separator"><p>B</p>')).to eq("A\n\n---\n\nB\n")
  end

  describe '#convert_inline' do
    it 'returns one line' do
      expect(described_class.new(links: links).convert_inline("<p>One\n<code>two</code></p>")).to eq('One `two`')
    end
  end

end
