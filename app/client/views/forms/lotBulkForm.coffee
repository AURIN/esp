Meteor.startup ->

  schemaArgs = Setter.clone(Lots.simpleSchema()._schema)
  _.each schemaArgs, (fieldArgs, key) ->
    fieldArgs.optional = true

  formName = 'lotBulkForm'
  collection = Lots
  schema = new SimpleSchema(schemaArgs)

  Form = Forms.defineModelForm
    name: formName
    schema: schema

    onCreate: ->
      unless @data.lots
        throw new Error('No docs provided')

    onRender: ->
      docs = @data.lots
      # Populate all form fields with any common values across docs if possible.
      _.each Form.getSchemaInputs(@), (input, key) ->
        isParamField = ParamUtils.hasPrefix(key)
        return unless isParamField
        $input = $(input.node)
        getParameterValue = (doc) -> SchemaUtils.getParameterValue(doc, key)
        commonValue = getParameterValue(docs[0])
        hasCommonValue = _.all docs.slice(1), (doc) ->
          commonValue == getParameterValue(doc)
        if hasCommonValue
          Forms.setInputValue($input, commonValue)

    onSubmit: (doc, modifier) ->
      console.log(arguments)
      # Perform the changes to the bulk form on each doc.
      template = getTemplate(@template)
      docs = template.data.lots
      dfs = []
      _.each docs, (doc) ->
        df = Q.defer()
        collection.update doc._id, modifier, (err, result) ->
          if err then df.reject(err) else df.resolve(result)
        dfs.push(df.promise)
      Q.all(dfs).then(
        => @done()
        (err) => @done(err)
      )
      false

  Form.helpers
    classes: -> Collections.createTemporary(Typologies.getAllocatableClassItems())
  
  isDropdown = ($input) -> $input.parent().hasClass('dropdown')
  getField = (name, template) -> getTemplate(template).$('[name="' + name + '"]')
  getTemplate = (template) -> Templates.getNamedInstance(formName, template)
