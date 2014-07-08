Template.collectionTable.created = function() {
  var items = this.data.items;
  var collection = this.data.collection;

  if (!collection) {
    if (items) {
      collection = Collections.get(items);
    } else {
      throw new Error('Either or both of "items" and "collection" attributes must be provided.');
    }
  } else {
    collection = Collections.get(collection);
  }
  // Store them for use in helpers.
  this.data.items = items;
  this.data.collection = collection;
  if (!collection) {
    console.warn('No collection provided.', this.data);
  }
};

Template.collectionTable.rendered = function() {
  // TODO(aramk) Refactor into a table.
  var $table = $(this.findAll('.reactive-table')).addClass('ui selectable table segment');
  var $filter = $(this.findAll('.reactive-table-filter'));
  var $toolbar = $filter.prev('.toolbar');
  $('.right.menu', $toolbar).append($filter.addClass('item'));
  $(this.findAll('input.form-control')).wrap('<div class="ui input"></div>');
  var $nav = $(this.findAll('.reactive-table-navigation'));
  var $footer = $('<tfoot><tr><th></th></tr></tfoot>');
  var colCount = $('tr:first th', $table).length;
  $('tr th', $footer).attr('colspan', colCount).append($nav);
  $('tbody', $table).after($footer);

  var data = this.data;
  var $btnCreate = $(this.find('.create.item')).click(onCreate);
  var $btnEdit = $(this.find('.edit.item')).click(onEdit);
  var $btnDelete = $(this.find('.delete.item')).click(onDelete);
  var $selectedRow;
  var selectedClass = data.selectedClass || 'selected';

  var collection = data.collection;
  var settings = data.settings;

  function getSelectedId() {
    return $selectedRow.attr('data-id');
  }

  function getSelectedModel() {
    return collection.findOne(getSelectedId());
  }

  function onCreate() {
    settings.onCreate && settings.onCreate(data, this);
  }

  function onEdit() {
    settings.onEdit && settings.onEdit(data, getSelectedModel(), this);
  }

  function onDelete() {
    settings.onDelete && settings.onDelete(this);
    if (confirm('Delete item?')) {
      collection.remove(getSelectedId());
      settings.onDeleted && settings.onDeleted(this);
    }
  }

  function onSelectionChange(item) {
    $btnEdit.add($btnDelete)[item ? 'show' : 'hide']();
    settings.onSelectionChange && settings.onSelectionChange(this);
  }

  onSelectionChange();

  var boundRows = {};
  function bindRow(row) {
    var $row = $(row);
    var id = $row.attr('data-id');
    if (!id) {
      console.warn('Could not bind row', id);
      return;
    }
    if (boundRows[id]) {
      return;
    }
    boundRows[id] = true;
    $row.click(function() {
      if ($selectedRow) {
        $selectedRow.removeClass(selectedClass);
        if ($selectedRow.is($(this))) {
          $selectedRow = null;
          // Deselection.
          onSelectionChange($selectedRow);
          return;
        }
      }
      // Selection.
      $selectedRow = $(this);
      $selectedRow.addClass(selectedClass);
      onSelectionChange($selectedRow);
    }).dblclick(function() {
      $selectedRow = $(this);
      onEdit();
    });
  }

  _.each($('tr[data-id]', $table), bindRow);

  collection.find({}).observe({
    added: function(doc) {
      // TODO(aramk) Temporary solution - observe changes in the table's template, or
      // provide a callback from within the library. We need to wait for the DOM element
      // to be constructed first.
      setTimeout(function() {
        var id = doc._id;
        var $td = $('[data-id="' + id + '"]', $table);
        bindRow($td.closest('tr'));
      }, 300);
    }
  });
};

Template.collectionTable.helpers({
  items: function() {
    return this.items || this.collection;
  },
  tableSettings: function() {
    return _.defaults(this.settings || {}, {
      rowsPerPage: 5,
      showFilter: true,
      useFontAwesome: true
    });
  }
});
