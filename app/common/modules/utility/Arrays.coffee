@Arrays =

  getRandomIndex: (array) ->
    index = Math.floor(Math.random() * array.length)
    index

  getRandomItem: (array) ->
    array[@getRandomIndex(array)]
