@Forms =

# We may pass the temporary collection as an attribute to autoform templates, so we need to
# define this to avoid errors since it is passed into the actual <form> HTML object.
  preventText: (obj) ->
    obj.toText = -> ''
    obj

  defineModelForm: (args) ->
    name = args.name
    TemplateClass = Template[name]
    unless TemplateClass
      throw new Error 'No template defined with name ' + name

    AutoForm.addHooks name,
      # Settings should be passed to the autoForm helper to ensure they are available in these
      # callbacks.
      onSubmit: (insertDoc, updateDoc, currentDoc) ->
        console.log 'onSubmit', arguments, @
        args.onSubmit?.apply(@, arguments)
        @template.data?.settings?.onSubmit?.apply(@, arguments)
      onSuccess: (operation, result, template) ->
        console.log 'onSuccess', arguments, @
        AutoForm.resetForm(name)
        args.onSuccess?.apply(@, arguments)
        template.data?.settings?.onSuccess?.apply(@, arguments)

    TemplateClass.helpers
      collection: -> Collections.get(args.collection)
      formName: -> name
      formType: -> if @doc then 'update' else 'insert'
      submitText: -> if @doc then 'Save' else 'Create'
      settings: -> Forms.preventText(@settings) if @settings?

    TemplateClass.events
      'click button.cancel': (e, template) ->
        e.preventDefault();
        args.onCancel?()
        template.data?.settings?.onCancel?()

    TemplateClass
