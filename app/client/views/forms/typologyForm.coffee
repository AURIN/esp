Meteor.startup ->
  Form = Forms.defineModelForm
    name: 'typologyForm'
    collection: 'Typologies'
    onSubmit: (insertDoc, updateDoc, currentDoc) ->
      insertDoc.test = 123
      updateDoc.$set = insertDoc
      console.log 'onSubmit', insertDoc, updateDoc
