Template.dropdown.rendered = function() {
  var items = Collections.getCollectionItems(this.data.items);
  var labelAttr = this.data.labelAttr || 'name';

  var $dropdown = $(this.find('.dropdown'));
  this.data.$dropdown = $dropdown;

  var $menu = $(this.find('.menu'));
  _.each(items, function(item) {
    var $item = $('<div class="item" data-value="' + item._id + '">' + item[labelAttr] + '</div>');
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
