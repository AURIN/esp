@Forms =

  FIELD_SELECTOR: '.form-group',

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

    if args.hooks?
      AutoForm.addHooks name, args.hooks

    Form.helpers
      collection: -> Collections.get(args.collection)
      formName: -> name
      formTitle: ->
        collectionName = Collections.getTitle(args.collection)
        (if @doc then 'Edit' else 'Create') + ' ' + Strings.singular(collectionName)
      formType: -> if @doc then 'update' else 'insert'
      submitText: -> if @doc then 'Save' else 'Create'
      settings: -> Forms.preventText(@settings) if @settings?

    Form.events
      'click button.cancel': (e, template) ->
        e.preventDefault();
        console.log 'onCancel', arguments, @
        args.onCancel?()
        template.data?.settings?.onCancel?()

    Form.rendered = ->
      console.debug 'Rendered form', @, arguments
      # Move the buttons to the same level as the title and content to allow using flex-layout.
      $buttons = $(@find('.buttons'))
      $crudForm = $(@find('.flex-panel'))
      if $buttons.length > 0 && $crudForm.length > 0
        $crudForm.append($buttons)
      $('[type="submit"]', $buttons).click ->
        $('form', $crudForm).submit();

      collection = Collections.get(args.collection)
      schema = collection?._c2?._simpleSchema;
      $schemaInputs = $(@findAll('[data-schema-key]'));

      if schema?
        schemaInputs = {}
        $schemaInputs.each ->
          $input = $(@)
          key = $input.attr('data-schema-key')
          field = schema.schema(key)
          schemaInputs[key] =
            node: @
            key: key
            field: field
        @schemaInputs = schemaInputs

        popupInputs = []
        for key, input of schemaInputs
          $input = $(input.node)
          field = input.field
          desc = field.desc
          # Add popups to the inputs contain definitions from the schema.
          if desc?
            popupInputs.push($input.data('desc', desc))
          # Add units into labels
          $label = $input.siblings('label')
          units = field.units
          if units?
            formattedUnits = Strings.format.scripts(units)
            $units = $('<div class="units">' + formattedUnits + '</div>');
            $labelContent = $('<div class="value">' + $label.html() + '</div>')
            $label.empty()
            $label.append($labelContent).append($units)

        addPopups = ->
          $(popupInputs).each ->
            $input = $(@)
            $input.data('desc')
            console.log('$input')
            $input.popup('setting', delay: 500, content: $input.data('desc'))

        removePopups = ->
          $(popupInputs).popup('destroy')
          popupInputs = []

        Deps.autorun ->
          helpMode = Session.get 'helpMode'
          if helpMode then addPopups() else removePopups()

      args.onRender?.apply(this, arguments)

    Form
