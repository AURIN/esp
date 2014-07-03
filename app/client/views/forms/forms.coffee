@Forms =

# We may pass the temporary collection as an attribute to autoform templates, so we need to
# define this to avoid errors since it is passed into the actual <form> HTML object.
  preventText: (obj) ->
    obj.toText = -> ''
    obj

  defineModelForm: (args) ->
    name = args.name
    Form = Template[name]
    unless Form
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

    Form.helpers
      collection: -> Collections.get(args.collection)
      formName: -> name
      formType: -> if @doc then 'update' else 'insert'
      submitText: -> if @doc then 'Save' else 'Create'
      settings: -> Forms.preventText(@settings) if @settings?

    Form.events
      'click button.cancel': (e, template) ->
        e.preventDefault();
        args.onCancel?()
        template.data?.settings?.onCancel?()

    Form.rendered = ->
      # Move the buttons to the same level as the title and content to allow using flex-layout.
      $buttons = $(@find('.buttons'))
      $crudForm = $(@find('.flex-panel'))
      if $buttons.length > 0 && $crudForm.length > 0
        $crudForm.append($buttons)
      $('[type="submit"]', $buttons).click ->
        $('form', $crudForm).submit();

      collection = Collections.get(args.collection)
      schema = collection._c2._simpleSchema;
      $schemaInputs = $('[data-schema-key]');
      console.log(collection, schema, $schemaInputs)

      popupInputs = []
      addPopups = ->
        console.log('adding popups')
        $schemaInputs.each ->
          $input = $(@)
          key = $input.attr('data-schema-key')
          field = schema.schema(key)
          desc = field.desc
          if desc
            $input.popup('setting', delay: 500, content: desc)
            popupInputs.push($input)
        console.log('popups', popupInputs)

      removePopups = ->
        console.log('removing popups', popupInputs)
        $(popupInputs).popup('destroy')
        popupInputs = []

      Deps.autorun ->
        helpMode = Session.get 'helpMode'
        if helpMode then addPopups() else removePopups()

    Form
