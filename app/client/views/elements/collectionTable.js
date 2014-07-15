var nextId = 1;
function getNextId() {
  return nextId++;
}
var sessionId = '_collectionTable_';
var selectedClass = 'selected';

function setReactiveVar(tableId, name, value) {
  console.log('setting reactive variable', value);
//  Session.set('_collectionTable_1:selectedItem', value);
  Session.set(getSessionVarName(tableId, name), value);
}

function getSessionVarName(tableId, name) {
  var value = sessionId + tableId + ':' + name;
  console.log('getSessionVarName', value);
  return sessionId + tableId + ':' + name;
}

function getReactiveVar(tableId, name) {
  return Session.get(getSessionVarName(tableId, name));
}

function configureSettings(data) {
  var items = data.items;
  var collection = data.collection;

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
  data.items = items;
  data.collection = collection;
//  data.collection = "testing";
  if (!collection) {
    console.warn('No collection provided.', data);
  } else {
    var collectionName = data.collectionName || Collections.getName(collection);
    if (collectionName) {
      var collectionId = Strings.firstToLowerCase(Strings.singular(collectionName));
      data.createRoute = data.createRoute || collectionId + 'Item';
      data.editRoute = data.editRoute || collectionId + 'Edit';
    } else {
      console.warn('No collection name provided', data);
    }
  }
  data._tableId = getNextId();
}

Template.collectionTable.rendered = function() {
//  configureSettings(this.data);
//  console.log('rendered', this.data);

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

  return;

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
    console.log('$selectedRow', $selectedRow);
    return $selectedRow ? $selectedRow.attr('data-id') : null;
  }

  function createItem() {
    console.log('createRoute', createRoute, settings.onCreate);
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
    console.log('editRoute', editRoute);
    console.log('settings', settings);
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

Template.collectionTable.events({
  'click table.selectable tbody tr': function(e, template) {
    function getRow(id) {
      return $(template.find('[data-id="' + id + '"]'))
    }

    var data = template.data;
    var model = this;
    var $row = $(e.target).closest('tr');
    console.log('click', this, arguments);

    var selectedItem = getReactiveVar(data._tableId, 'selectedItem');
    if (selectedItem) {
      var $selectedRow = getRow(selectedItem.model._id);
      console.log('$selectedRow', $selectedRow);
      $selectedRow.removeClass(selectedClass);
      if ($selectedRow.is($row)) {
        // Deselection.
        setReactiveVar(data._tableId, 'selectedItem', null);
        return;
      }
    }
    var item = {
      model: model,
//      row: $row[0]
    };
    console.log('item', item);
    $row.addClass(selectedClass);
//    var $selectedItem = template.data.$selectedItem;
//    if ($selectedItem) {
//
//    }
    setReactiveVar(data._tableId, 'selectedItem', item);
  },
  'dblclick table.selectable tbody tr': function(e, template) {
    // TODO(aramk)
  }
});

Template.collectionTable.helpers({
  _settings: function() {
    var data = this;
    configureSettings(data);
    setReactiveVar(data._tableId, 'selectedItem', null);
    return {
      items: data.items || data.collection,
      tableSettings: _.defaults(data.settings, {
        rowsPerPage: 10,
        showFilter: true,
        useFontAwesome: true
      }),
      tableId: data._tableId
    };
  },
  selectedItem: function() {
    var data = this;
    var value = getReactiveVar(data._tableId, 'selectedItem');
//    var value = Session.get(getSessionVarName(data._tableId, 'selectedItem'));
//    var value = Session.get('_collectionTable_1:selectedItem');
    console.error('selectedItem', value);
    return value;
  }
//  items: function() {
//    console.log('items', this);
////    console.log('items', this, this.items, this.collection);
//
//
//    configureSettings(this);
//    return this.items || this.collection;
//  },
//  tableSettings: function() {
//    console.log('tableSettings', this);
//    return _.defaults(this.settings, {
//      rowsPerPage: 10,
//      showFilter: true,
//      useFontAwesome: true
//    });
//  },
//  selectedItem: function () {
//    Session.get('collectionTable_selectedItem_' + getNextId());
//  }
});
