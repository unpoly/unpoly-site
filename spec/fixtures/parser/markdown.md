Markdown test page
==================

A page with one of everything the Markdown twins convert. Its twin is pinned by a
golden file in `spec/fixtures/markdown/` (see markdown_twins_spec.rb).

It links to [`up.render()`](/up.render), to [an anchor](/up.render#options.target), to
[a section on this page](#code-blocks) and to [a page without a twin](/imprint).
Code spans like `test.module.function()` link themselves.


Code blocks
-----------

```html
<a href="/a" up-follow>A</a> <!-- mark: up-follow -->
<div up-main>Main</div> <!-- mark-line -->
<span>Kept</span> <!-- chip: A chip stays without its directive -->
```

```js
// label: A labelled block
let result = up.render('.foo') // result: up.RenderJob
```


Lists and tables
----------------

- One
- Two with `code`
  - Nested
- Three

1. First
2. Second

| Attribute | Effect |
| --- | --- |
| `[up-follow]` | Follows a link |
| `[up-target]` | Targets a fragment |


Admonitions and media {#media}
---------------------

> [tip]
> A tip with **bold** and _emphasis_.

![A screenshot of nothing in particular](images/test-screenshot.png)

<video src="images/test-video.webm" controls width="600" aria-label="A video of nothing in particular"></video>

<div embed="fragment-updates-diagram"></div>


@page test.markdown
