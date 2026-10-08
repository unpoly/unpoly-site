---
area: "API"
url: "http://unpoly.test/test.markdown"
---
<nav aria-label="Unpoly docs">[All docs](http://unpoly.test/index.md) · [API reference](http://unpoly.test/api.md)</nav>

# Markdown test page

A page with one of everything the Markdown twins convert. Its twin is pinned by a golden file in `spec/fixtures/markdown/` (see markdown_twins_spec.rb).

It links to [`up.render()`](http://unpoly.test/up.render.md), to [an anchor](http://unpoly.test/up.render.md#options.target), to [a section on this page](#code-blocks) and to [a page without a twin](http://unpoly.test/imprint). Code spans like [`test.module.function()`](http://unpoly.test/test.module.function.md) link themselves.

<nav aria-label="Contents">

#### Contents

- [Code blocks](#code-blocks)
- [Lists and tables](#lists-and-tables)
- [Admonitions and media](#media)

</nav>

## Code blocks {#code-blocks}

```html
<a href="/a" up-follow>A</a>
<div up-main>Main</div>
<span>Kept</span> <!-- A chip stays without its directive -->
```

```js
// A labelled block
let result = up.render('.foo') // result: up.RenderJob
```

## Lists and tables {#lists-and-tables}

- One
- Two with `code`
  - Nested
- Three

1. First
2. Second

| Attribute | Effect |
| --- | --- |
| [`[up-follow]`](http://unpoly.test/up-follow.md) | Follows a link |
| `[up-target]` | Targets a fragment |

## Admonitions and media {#media}

> #### Tip
>
> A tip with **bold** and _emphasis_.

![A screenshot of nothing in particular](http://unpoly.test/images/api/test-screenshot.png)

[Video: A video of nothing in particular](http://unpoly.test/images/api/test-video.webm)

[Diagram: How Unpoly uses a server response](http://unpoly.test/test.markdown#fragment-updates-diagram)

Three requests, each shown across four columns. The server always responds with a complete page. Unpoly uses only the fragments that changed, leaving the rest of the screen in place. A server may optionally respond with those fragments alone.

