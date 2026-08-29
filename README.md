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

This repo should have a lot more tests.

The code that parses documentation comments is covered in `spec/lib`. There are a few
Capybara feature specs for the site itself in `spec/features`.\
Run them all with `bundle exec rspec`.


## Deployment

1. Commit and push changes in `unpoly-site`.
2. Commit and push changes in `unpoly`, which you might have changed while reviewing the
   documentation output.
3. Run `bundle exec cap v3 deploy` to push the changes to <https://unpoly.com>. Static
   files will be built during deployment, including a broken-link check over the whole
   site.
4. Update the full text index as printed at the end of the deploy:
   `STAGE=v3 ALGOLIA_KEY=secret bundle exec rake algolia:push_all`
