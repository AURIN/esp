_.extend ParamUtils,
  
  getParamSchema: (paramId) ->
    paramId = @removePrefix(paramId)
    Entities.ParametersSchema.schema(paramId) ? Projects.ParametersSchema.schema(paramId)
