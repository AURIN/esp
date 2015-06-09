class @Csv

  constructor: ->
    @rows = []

  # @param {CsvRow|Array}
  addRow: (args) ->
    row = args
    if Types.isArray(args)
      row = new CsvRow(args)
    unless row instanceof CsvRow
      throw new Error('Invalid arguments')
    @rows.push(row)

  toString: ->
    rowsStr = _.map @rows, (row) -> row.toString()
    rowsStr.join('\n')

class @CsvRow

  # @param {Array} cells
  constructor: (cells) ->
    unless Types.isArray(cells)
      throw new Error('Invalid arguments')
    @cells = cells

  toString: ->
    # Add two double quotes in place of one to escape.
    cells = _.map @cells, (cell) ->
      unless cell?
        return ''
      cell.toString().replace('"', '""')
    '"' + cells.join('","') + '"'
