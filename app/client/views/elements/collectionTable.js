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
    collection = Collections.resolve(collection);
  }
  // Store them for use in helpers.
  this.data.items = items;
  this.data.collection = collection;
  if (!collection) {
    console.warn('No collection provided.', this.data);
  } else {
    var collectionName = this.data.collectionName || Collections.getName(collection);
    if (collectionName) {
      var collectionId = Strings.firstToLowerCase(Strings.singular(collectionName));
      this.data.createRoute = this.data.createRoute || collectionId + 'Item';
      this.data.editRoute = this.data.editRoute || collectionId + 'Edit';
    } else {
      console.warn('No collection name provided', this.data);
    }
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
  var settings = data.settings;

  var $btnCreate = $(this.find('.create.item')).click(createItem);
  var $btnEdit = $(this.find('.edit.item')).click(editSelectedRow);
  var $btnDelete = $(this.find('.delete.item')).click(deleteSelectedRow);
  var $selectedRow;
  var selectedClass = data.selectedClass || 'selected';

  var collection = data.collection;
  var createRoute = data.createRoute;
  var editRoute = data.editRoute;

  function onSelectionChange(item) {
    $btnEdit.add($btnDelete)[item ? 'show' : 'hide']();
  }

  function getSelectedId() {
    return $selectedRow.attr('data-id');
  }

  function createItem() {
    settings.onCreate ? settings.onCreate(createHandlerContext()) : Router.go(createRoute);
  }

  function createHandlerContext(extraArgs) {
    var model = $selectedRow ? $selectedRow.data('model') : null;
    return _.extend({id: getSelectedId(), selectedRow: $selectedRow, model: model,
      collection: collection, createRoute: createRoute, editRoute: editRoute}, extraArgs);
  }

  function editSelectedRow(args) {
    var defaultHandler = function() {
      Router.go(editRoute, {_id: getSelectedId()});
    };
    if (settings.onEdit) {
      settings.onEdit(createHandlerContext(_.extend({defaultHandler: defaultHandler}, args)));
    } else {
      defaultHandler();
    }
  }

  function deleteSelectedRow() {
    if (confirm('Delete item?')) {
      settings.onDelete ? settings.onDelete(createHandlerContext()) :
          collection.remove(getSelectedId());
    }
  }

  onSelectionChange();
  var $rows = $(this.findAll('table.selectable tbody tr'));
  $rows.click(function() {
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
  }).dblclick(function(e) {
    $selectedRow = $(this);
    editSelectedRow({event: e});
  });
};

Template.collectionTable.helpers({
  items: function() {
    return this.items || this.collection;
  },
  tableSettings: function() {
    return _.defaults(this.settings, {
      rowsPerPage: 10,
      showFilter: true,
      useFontAwesome: true
    });
  }
});
