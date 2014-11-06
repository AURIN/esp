@ParamUtils =
  
  _prefix: 'parameters'
  _rePrefix: /^parameters\./

  addPrefix: (id) ->
    if @_rePrefix.test(id)
      id
    else
      @_prefix + '.' + id
  
  removePrefix: (id) -> id.replace(@_rePrefix, '')
  
  hasPrefix: (id) -> @._rePrefix.test(id)
  
  getParamSchema: (paramId) ->
    paramId = @removePrefix(paramId)
    ParametersSchema.schema(paramId) ? ProjectParametersSchema.schema(paramId)
  
  getLabel: (paramId) ->
    schema = @getParamSchema(paramId)
    label = schema.label
    return label if label?
    label = _.last(paramId.split('.'))
    Strings.toTitleCase(Strings.toSpaceSeparated(label))
