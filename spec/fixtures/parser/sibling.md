# test.sibling

A namespace documented in a doc file beside its source file.

@namespace test.sibling

-----

# test.sibling.function()

A function documented in a doc file.

Prose may contain a thematic break of three dashes:

---

And a setext heading underlined with dashes:

Setext heading
--------------

```text
A code block may contain a line of dashes:

-----

# And a line that looks like an H1
```

@function test.sibling.function
@param {string} target
  The target.

  ```js
  -----
  ```
@return {boolean}
@stable

-----

# test.sibling.Thing#method()

An instance method, headed by its menu title.

@function test.sibling.Thing#method
@stable

-----

# [test-sibling]

A selector.

@selector [test-sibling]
@param {string} [test-sibling-option]
  An option.
@stable

-----

# new test.sibling.Thing()

A constructor.

@constructor test.sibling.Thing
@stable

-----

# test.sibling.Thing#element

A property, headed by its menu title.

@property test.sibling.Thing#element
@stable

-----

# test.sibling.Thing.prototype.other

A property, headed by its full name.

@property test.sibling.Thing.prototype.other
@stable

-----

# test:sibling:event

An event.

@include test.sibling.partial

@event test:sibling:event
@stable

-----

# test.sibling.partial

Text from a partial.

@partial test.sibling.partial
