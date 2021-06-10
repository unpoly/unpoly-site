  ###**
  Test module
  ===========

  @module test.module
  ###

  ###**
  @function test.module.function
  @param {string|Element} target
  @param {Object} [options]
  @return {boolean}
  @stable
  ###

  ###**
  @function test.module.functionWithDefault
  @param {string} [arg='default value']
  @stable
  ###

  ###**
  @function test.module.stableFunction
  @stable
  ###

  ###**
  @function test.module.experimentalFunction
  @experimental
  ###

  ###**
  @function test.module.deprecatedFunction
  @deprecated use something else
  ###

  ###**
  @function test.module.functionWithParamsNote
  @params-note All options from other function may be used
  @param {Object} options
  @stable
  ###

  ###**
  @function test.module.referencingFunction
  @see test.module.function
  @stable
  ###

  ###**
  @function test.module.essentialFunction
  @stable
  @essential
  ###

  ###**
  @function test.module.nonessentialFunction
  @stable
  ###

  ###**
  @selector [test-module-selector]
  @stable
  ###

  ###**
  @property test.module.property
  @param {string} value
  @stable
  ###

  ###**
  @property test.module.objectProperty
  @param {string} objectProperty.key1
  @param {number} objectProperty.key2
  @stable
  ###

  ###**
  @property test.module.propertyWithArrayDefault
  @param {Array<string>} [propertyWithArrayDefault=['foo', 'bar']]
  @stable
  ###
