# Up.js guide and API

These are the sources for the website of Up.js, [upjs.io](http://upjs.io).

If you are looking for Up.js itself, visit [github.com/makandra/upjs](https://github.com/makandra/upjs).


## Development

We use [Middleman](https://middlemanapp.com/) to generate this site statically.

The pages are parsed from [YUIDoc comments](http://yui.github.io/yuidoc/syntax/) like [this one](https://github.com/makandra/upjs/blob/9e12839106b25f8428684a8ba3b4162d3f03038e/lib/assets/javascripts/up/flow.js.coffee#L31).

Mind the block comment syntax with an additional asterisk (`*`) after the opening tag:

    ###*
    Foo
    ###

The Middleman site expects you to have checked out the [Up.js repo](https://github.com/makandra/upjs) in the same folder like this:

```
projects/
  upjs
  upjs-guide
```

This way you can make changes to the documentation and see its HTML output immediately.
