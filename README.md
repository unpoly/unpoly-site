# Unpoly guide and API

These are the sources for [unpoly.com](https://unpoly.com): the site's parser, templates,
stylesheets and JavaScript.

If you are looking for the source code of the Unpoly framework, visit
[github.com/unpoly/unpoly](https://github.com/unpoly/unpoly).


## What lives where

The [unpoly.com](https://unpoly.com) site is implemented by two repositories:

-  **[`unpoly/unpoly`](https://github.com/unpoly/unpoly)** holds most of the textual content (API references, guide pages).\
   Written as Markdown with JSDoc-like directives.
- **`unpoly/unpoly-site`** (this repo) holds the HTML templates, CSS, and JS.\
  It also implements a parser that reads content from `unpoly/unpoly`.

Documentation content is written **in the `unpoly/unpoly` repository, next to the code it
describes**, so that a change to a feature and a change to its documentation happen in the
same commit and cannot drift apart. Nothing in `source/api` is a page you write; those are
templates that the parser fills.

The `unpoly/unpoly-site` repo only holds content for a few pages, all implemented in `source/`:

- the start page
- `/install`
- `/tutorial`
- `/support`


## Project overview

- [unpoly.com](https://unpoly.com) is a static site. It uses Unpoly for its frontend.
- We use [Middleman](https://middlemanapp.com/), a static site generator based on Ruby.
- Page sources can be found in `source`. We mostly use ERB templates.
- API references and module overviews are not Middleman pages. They are parsed live from
  the Unpoly source code. See *How API documentation is parsed*.
- There is a symlink pointing to a local copy of the Unpoly source code in
  `vendor/unpoly-local`. This code is used both to parse the documentation *and* to
  provide the Unpoly JavaScript and stylesheets for the site itself. See *Local
  development* below.
- Frontend assets can be found in `source/javascripts` and `source/stylesheets`. They are
  compiled with Sprockets, there is no Webpack or another bundler. The Sprockets
  integration in Middleman 4 works just like the classic Rails asset pipeline.
- Helper functions and Middleman configuration can be found in `config.rb`.
- The site is deployed by copying the static build files to
  [unpoly.com](https://unpoly.com). We use Capistrano to build and deploy with a single
  command. See *Deployment*.


## How API documentation is parsed

Ruby code in `lib/unpoly/guide` parses documentation comments into an AST-like structure
(the `Unpoly::Guide` namespace).

It scans every `.js` and `.md` file under `vendor/unpoly-local/src`. In a `.js` file it
picks up comments opening with `/*-`; a `.md` file is one documentation block in its
entirety. Each block declares what it documents (`@function`, `@selector`, `@page`, …),
and the parser resolves cross-references, partials and inherited params between them.

Middleman proxies set up in `config.rb` then create one page per parsed symbol, rendered
through `source/api/feature_template.html.erb` and
`source/api/interface_template.html.erb`.

Documentation changes are picked up by reloading. You need to restart the development
server when you add a *new* symbol or page, because the proxies are built at boot.


## HTML and CSS structure

- We use the BEM (Block/Element/Modifier) naming convention to prevent name clashes and
  accidental style inheritance. All components are implemented as BEM blocks. We use the
  terms "blocks" and "components" interchangeably.
- We use a custom BEM naming convention that only uses double dashes (`--`), never double
  underscores (`__`). All names are kebab-cased.
- Every block lives in a file of its own in `source/stylesheets/guide/blocks`, named after
  the block. Files there are picked up by `require_tree`, so a new block needs no import.

### Blocks

A simple block is a class on a `<div>`, `<span>` or any other element:

    <a href="/install" class="hyperlink">Install</a>

### Elements

The children of a block ("elements" in BEM lingo) are all prefixed with the block name and
two dashes (`--`):

    <div class="menu">
      <div class="menu--search">…</div>
      <div class="menu--nodes">…</div>
    </div>

Do not use double underscores (`__`) to separate block and element names.

Where possible, only have a single nesting level (a block with many children). Where deeper
nesting has big advantages, the class name still only contains a single nesting depth
(`block--last-element-depth`):

    <div class="feature">
      <div class="feature--param">
        <div class="feature--param-info">…</div>
        <div class="feature--param-details">…</div>
      </div>
    </div>

### Modifiers for variants

To offer variants of a block, define modifier classes that can be added to the block class.
Modifiers are prefixed with a single dash (`-`):

    <span class="tag -teal">required</span>

Both blocks and elements can have modifiers. In SASS a modifier is nested into the block it
belongs to:

    .tag
      background-color: var(--color)

      &.-teal
        --color: #{$COLOR_GREEN_SEA}

Modifiers do NOT use prepositions (NOT like `.is-teal`) and they do NOT prefix the block
name (NOT like `.tag--teal`).

Many modifiers are generated from parsed documentation: a feature's visibility becomes
`-stable`, `-experimental`, `-deprecated` or `-internal`, and a menu node's kind becomes
`-page`, `-group` or `-interface`.

### The same names in Ruby and JavaScript

BEM names are not limited to templates and stylesheets. They are also built in Ruby helpers
(`config.rb`, `lib/unpoly/guide`) and used by the components in `source/javascripts`, both
as selectors and as classes toggled at runtime. When you rename a block, grep for its name
in all four places: stylesheets, ERB templates, Ruby and JavaScript.


## Local development

Every variant below expects `unpoly` and `unpoly-site` to be checked out in the same
parent folder:

    projects/
      unpoly/
      unpoly-site/

That's because the symlink `vendor/unpoly-local` — committed in this repo — points at
`../unpoly`, and everything is read through it: the documentation content, and the Unpoly
build in `unpoly/dist` that the site uses for its own frontend.

### Recommended: boot the dev environment in `unpoly`

Best when you are writing documentation, and still fine when you are working on the site.

Install the Ruby version from `.ruby-version` and run `bundle install` here once. Then, in
the `unpoly` directory:

    bin/dev

This boots this site at <http://localhost:4567> alongside Unpoly's own build watcher, so
`unpoly/dist` stays current as you edit the framework — no manual build, and no second
terminal. See
[Setting up a dev environment](https://github.com/unpoly/unpoly/blob/master/docs/contributing/dev-environment.md)
in that repository.

### Alternative: a Middleman server on its own

Use this when you only want to work on the site and don't need a live build of the
framework. You are responsible for `unpoly/dist` yourself: if it's missing or stale, run
`npm run build` in the `unpoly` directory.

- Install the Ruby version from `.ruby-version`.
- Install dependencies with `bundle install`.
- Start a development server with `bundle exec middleman server`.
- Test your changes on <http://localhost:4567>.

### Alternative: a DevContainer

Same scope as above — the site alone, with `unpoly/dist` your responsibility — but without
installing Ruby. If you're using an editor such as VSCode and have Docker available, you
can use the DevContainer configuration provided.

1. Open the project in VSCode.
2. When prompted, choose to Reopen in Devcontainer.

Once inside the DevContainer, use `bundle exec middleman server` and `bundle exec rspec` as
you normally would.

### Alternative: Docker Compose

The same container without VSCode. From inside the `unpoly-site` folder:

    docker compose -p unpoly-site -f .devcontainer/docker-compose.yml run --service-ports app

Once the container is running, you can browse documentation from the outside at
<http://localhost:4567>.


## Tests

Run the test suite with `bundle exec rspec`. It also runs on GitHub Actions for every
push to `master` and for every pull request.

Tests read the documentation through `vendor/unpoly-local` like the site does, so they see
the content of whatever revision is checked out there. A missing `@stable` tag in the
Unpoly sources will fail the suite here.

- **`spec/lib`** covers the parser and the objects it builds (the `Unpoly::Guide`
  namespace) with fast unit tests. What is worth covering here is what the HTML templates
  call: the `guide_path` of a documentable, the HTML that `MarkdownRenderer` produces, the
  features and topics an interface offers to the menu.
- **`spec/features`** covers the site itself with Capybara feature specs. They all run in a
  headless Chrome (`js: true`), since most of what the site does — loading the menu,
  filtering it, updating fragments instead of reloading — only happens with JavaScript.
  Use `NO_HEADLESS=1 bundle exec rspec` to watch them in a visible browser.
- **`spec/fixtures/parser`** holds doc comments that the parser reads *in addition to* the
  Unpoly sources, as test data for parsing rules. Note that they are parsed in a
  production build as well, where they become pages of their own.

We aim for a middle ground on coverage: describe public API and behavior rather than
implementation details, and keep the browser tests to core journeys that a unit test
cannot reach. A parsing rule is worth a fixture and one expectation; it does not need a
feature spec of its own.


## Deployment

1. Commit and push changes in `unpoly-site`.
2. Commit and push changes in `unpoly`, which you might have changed while reviewing the
   documentation output.
3. Run `bundle exec cap v3 deploy` to push the changes to <https://unpoly.com>. Static
   files will be built during deployment, including a broken-link check over the whole
   site.
4. Update the full text index as printed at the end of the deploy:
   `STAGE=v3 ALGOLIA_KEY=secret bundle exec rake algolia:push_all`
