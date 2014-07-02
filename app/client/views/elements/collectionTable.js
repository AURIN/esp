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

  var $btnCreate = $(this.find('.create.item')).click(createItem);
  var $btnEdit = $(this.find('.edit.item')).click(editSelectedRow);
  var $btnDelete = $(this.find('.delete.item')).click(deleteSelectedRow);
  var $selectedRow;
  var selectedClass = this.data.selectedClass || 'selected';

  var collection = this.data.collection;
  var createRoute = this.data.createRoute;
  var editRoute = this.data.editRoute;

  function createItem() {
    Router.go(createRoute);
  }

  function onSelectionChange(item) {
    $btnEdit.add($btnDelete)[item ? 'show' : 'hide']();
  }

  function getSelectedId() {
    return $selectedRow.attr('data-id');
  }

  function editSelectedRow() {
    Router.go(editRoute, {_id: getSelectedId()});
  }

  function deleteSelectedRow() {
    if (confirm('Delete item?')) {
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
  }).dblclick(function() {
    $selectedRow = $(this);
    editSelectedRow();
  });
};

Template.collectionTable.helpers({
  items: function() {
    return this.items || this.collection;
  },
  tableSettings: function() {
    var settings = _.defaults(this.settings || {}, {
      rowsPerPage: 5,
      showFilter: true,
      useFontAwesome: true
    });
    console.log('settings', settings);
    return settings;
  }
});
