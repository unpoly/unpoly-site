# Unpoly guide and API

These are the sources for the website of Unpoly, [unpoly.com](https://unpoly.com).

If you are looking for Unpoly itself, visit [github.com/unpoly/unpoly](https://github.com/unpoly/unpoly).


## Development

We use [Middleman](https://middlemanapp.com/) to generate this site statically.

The pages are parsed from [YUIDoc comments](http://yui.github.io/yuidoc/syntax/) like [this one](https://github.com/unpoly/unpoly/blob/9e12839106b25f8428684a8ba3b4162d3f03038e/lib/assets/javascripts/up/flow.js.coffee#L31).

Mind the block comment syntax with an additional asterisk (`*`) after the opening tag:

    ###**
    Foo
    ###

The Middleman site expects you to have checked out the [Unpoly repo](https://github.com/unpoly/unpoly) in the same folder like this:

```
projects/
  unpoly
  unpoly-guide
```

This way you can make changes to the documentation and see its HTML output immediately.


## Deploying

1. Commit and push changes in `unpoly-guide`.
2. Commit and push changes in `unpoly`, which you might have changed while reviewing the documentation output.
3. Run `cap deploy` to push the changes to <https://unpoly.com>. Static files will be built during deployment.

