AutoForm.inputValueHandlers({
  '.selection.dropdown': function () {
    return $('input', this).val();
  }
});

Template.dropdown.rendered = function() {
  var items = Collections.getItems(this.data.items);
  var labelAttr = this.data.labelAttr || 'name';
  var valueAttr = this.data.valueAttr || '_id';

  var $dropdown = $(this.find('.dropdown'));
  this.data.$dropdown = $dropdown;

  var $menu = $(this.find('.menu'));
  _.each(items, function(item) {
    var $item = $('<div class="item" data-value="' + item[valueAttr] + '">' + item[labelAttr] + '</div>');
    $menu.append($item);
  });

  // Initialize after all items are added to ensure events are bound.
  $dropdown.dropdown();

  // Set initial value
  var value = this.data.value;
  if (value) {
    $dropdown.dropdown('set value', value).dropdown('set selected', value);
  }
};

Template.dropdown.helpers({

  cls: function () {
    return this.name.replace('.', '-');
  }

});
