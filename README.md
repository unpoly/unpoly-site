# Unpoly guide and API

These are the sources for the website of Unpoly, [unpoly.com](http://unpoly.com).

If you are looking for Unpoly itself, visit [github.com/makandra/upjs](https://github.com/makandra/upjs).


## Development

We use [Middleman](https://middlemanapp.com/) to generate this site statically.

The pages are parsed from [YUIDoc comments](http://yui.github.io/yuidoc/syntax/) like [this one](https://github.com/makandra/upjs/blob/9e12839106b25f8428684a8ba3b4162d3f03038e/lib/assets/javascripts/up/flow.js.coffee#L31).

Mind the block comment syntax with an additional asterisk (`*`) after the opening tag:

    ###*
    Foo
    ###

The Middleman site expects you to have checked out the [Unpoly repo](https://github.com/makandra/upjs) in the same folder like this:

```
projects/
  upjs
  upjs-guide
```

This way you can make changes to the documentation and see its HTML output immediately.


## Deploying

- In the `upjs-guide` repo, call `middleman build`. This will generate/update the static HTML files.
- Commit and push changes in `upjs-guide`, including the static HTML files you just generated.
- Commit and push changes in `upjs`, which you probably changed as well.
- Run `cap deploy` to push the changes to <http://unpoly.com>.

