@Strings =

# @returns {String} The string converted to title case.
  toTitleCase: (str) ->
    parts = str.split(/\s+/)
    title = ''
    for part, i in part
      if part != ''
        title += part.slice(0, 1).toUpperCase() + part.slice(1, part.length);
        if i != parts.length - 1 and parts[i + 1] != ''
          title += ' '
    title

  firstToLowerCase: (str) ->
    str.replace /(^\w)/, (firstChar) -> firstChar.toLowerCase()

  firstToUpperCase: (str) ->
    str.replace /(^\w)/, (firstChar) -> firstChar.toUpperCase()

# TODO(aramk) Improve naive pluralize methods.

  singular: (plural) ->
    plural.replace /s$/, ''

  plural: (singular) ->
    singular + 's'
