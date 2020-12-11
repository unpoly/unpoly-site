# Unpoly guide and API

These are the sources for [unpoly.com](https://unpoly.com).

If you are looking for the source code of the Unpoly framework, visit [github.com/unpoly/unpoly](https://github.com/unpoly/unpoly).


## Project overview

- [unpoly.com](https://unpoly.com) is a static site. It uses Unpoly for its frontend.
- We use [Middleman](https://middlemanapp.com/), a static site generator based on Ruby. 
- Page sources can be found in `source`. We mostly use ERB templates.
- All API references and package overviews are parsed live from the Unpoly source code.
  See *Updating API documentation* and *How API documentation is parsed*.
- There is a symlink pointing to a local copy of the Unpoly source code in `vendor/unpoly-local` .
  This code is used both to parse the API documentation *and* to provide
  the Unpoly JavaScript and stylesheets for the site. See *Setting up local development* below.
- Frontend assets can be found in `source/javascripts` and `source/stylesheets`.
  They are compiled with Sprockets, there is no Webpack.
  The sprockets integration in Middleman 4 works just like the classic Rails asset pipeline.
- Helper functions and Middleman configuration can be found in `config.rb`.
- The site is deployed by copying the static build files to [unpoly.com](https://unpoly.com).
  We use Capistrano to build and deploy with a single command. See *Deployment*.
  

## Updating API documentation

The API docs for Unpoly functions, selectors, etc. are not maintained in *this* repo but in documentation comments in [unpoly/unpoly](https://github.com/unpoly/unpoly). Every API page on [unpoly.com](https://unpoly.com) will have a *Change this page* link
leading to the underlying comment on GitHub.

**When you make a change to an API documentation, make a PR in [unpoly/unpoly](https://github.com/unpoly/unpoly). Make sure to edit files in `lib` and
not in `dist`.** Files in `dist` are rewritten with every release.

Accordingly all API references and package overviews are *not* built as Middleman pages. Instead the info is parsed from documentation comments in the Unpoly source code in `vendor/unpoly-local`.

Documentation comments look like this in JavaScript files (`.js`, `.mjs`):

```
/***
Linking to fragments
====================

The `up.link` module lets you build links that update fragments instead of entire pages.

@module up.link
*/
```

In a CoffeeScript file (`.coffee`) they will look like this::

```
###**
Linking to fragments
====================

The `up.link` module lets you build links that update fragments instead of entire pages.

@module up.link
###
```

The documentation syntax is inspired by [YUIDoc](http://yui.github.io/yuidoc/syntax/).
We added many extensions to that syntax to document events, selectors, etc.

Documentation changes should be picked up by reloading.
You probably need to restart your development server when you create a *new*
API reference page.


## How API documentation is parsed

There is Ruby code in `lib/unpoly/guide` that parses documentation comments
into an AST-like structure (`Unpoly::Guide` namespace).

Middleman proxies have been setup in `config.rb` so one Middleman page
is dynamically created for each symbol in the API comments.



## Interactive examples

You can create CodePen-like, interactive examples by adding a folder in 
the `examples` directory.

This is currently only used by the [Tutorial](https://unpoly.com/tutorial).

Examples are limited in that there is no active server component, your example
needs to work with static files alone. We should probably move our examples
to something like [Glitch](https://glitch.com/) because of this.


## Renaming paths

When you rename anything with a URL, e.g. by renaming an API function, please
add a `RewriteRule` to `source/.htaccess` to existing links will keep working.


## Setting up local development

- Check out the repo
- Make sure that the symlink `vendor/unpoly-local` points to a copy
  of the source codes for the Unpoly framework. By default it is expected
  that the source code for unpoly.com and the framework are checked out in the same folder:
  
      projects/
        unpoly/
        unpoly-site/

- Install the Ruby version from `.ruby-version`
- Install dependencies with `bundle install`
- Start a development server with `bundle exec middleman server`
- Test your changes on `http://localhost:4567`


## Tests

This repo should have a lot more tests.

The code that parses documentation comments has a few tests in `spec`.\
Run them with `bundle exec rspec`.

There are no E2E tests for the site itself.
We should have feature specs with Capybara for that.


## Deployment

1. Commit and push changes in `unpoly-site`.
2. Commit and push changes in `unpoly`, which you might have changed while reviewing the documentation output.
3. Run `bundle exec cap production deploy` to push the changes to <https://unpoly.com>. Static files will be built during deployment.

