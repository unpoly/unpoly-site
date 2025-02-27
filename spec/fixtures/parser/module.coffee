  ###-
  Test module
  ===========

  @module test.module
  ###

  ###-
  @function test.module.function
  @param {string|Element} target
  @param {Object} [options]
  @return {boolean}
  @stable
  ###

  ###-
  @function test.module.functionWithDefault
  @param {string} [arg='default value']
  @stable
  ###

  ###-
  @function test.module.stableFunction
  @stable
  ###

  ###-
  @function test.module.experimentalFunction
  @experimental
  ###

  ###-
  @function test.module.deprecatedFunction
  @deprecated use something else
  ###

  ###-
  @function test.module.functionWithParamsNote
  @params-note All options from other function may be used
  @param {Object} options
  @stable
  ###

  ###-
  @function test.module.referencingFunction
  @see test.module.function
  @stable
  ###

  ###-
  @function test.module.nonessentialFunction
  @stable
  ###

  ###-
  @selector [test-module-selector]
  @stable
  ###

  ###-
  @property test.module.property
  @param {string} value
  @stable
  ###

  ###-
  @property test.module.objectProperty
  @param {string} objectProperty.key1
  @param {number} objectProperty.key2
  @stable
  ###

  ###-
  @property test.module.propertyWithArrayDefault
  @param {Array<string>} [propertyWithArrayDefault=['foo', 'bar']]
  @stable
  ###

  ###-
  @function test.module.noTypeButCurlyBracesInDescription
  @param foo
    Curly { braces } in the description are not parsed as types
  @return
    Curly { braces } in the description are not parsed as types
  ###

  ###-
  @function test.module.paramVisibilities
  @param options.foo
    Foo description
    @internal
  @param options.bar
    Bar description
  @param options.baz
    Baz description
    @internal
  @experimental
  ###

  ###-
  @function test.module.paramSections
  @section First section
    @param options.foo
      Foo description
    @param options.bar
      Bar description
  @section Second section
    @param options.baz
      Baz description
  @stable
  ###

  ###-
  Line before partial
  @include test.partial
  Line after partial

  @function test.module.featureIncludingPartial
  @experimental
  ###

  ###-
  @partial test.structuralPartial

  @param fooFromPartial
    Foo description from partial
  @param barFromPartial
    Bar description from partial
  ###

  ###-
  @function test.module.featureIncludingStructuralPartial
  @include test.structuralPartial
  @experimental
  ###

  ###-
  @function test.module.featureMixingPartial
  @mix test.structuralPartial
    @param barFromPartial
      Foo description override
  @experimental
  ###

  ###-
  @function test.module.featureMixingPartialInSection
  @section Arguments
    @mix test.structuralPartial
      @param barFromPartial
        Foo description override
  @experimental
  ###
