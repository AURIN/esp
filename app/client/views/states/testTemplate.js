Template.testTemplate.created = function () {
  this.data = this.data || {};
  this.data.test = 123;
  this.data.in = 000;
  console.log('created', this.data);
};

Template.testTemplate.rendered = function () {
  console.log('rendered', this.data);
};

Template.testTemplate.helpers({
  generateSettings: function () {
    console.log('generateSettings', this, this.data);
    return {
      testB: function () {
        console.log('testB');
        return 456;
      }
    }
  },
  test: function() {
    console.log('helper', this);
    return 123;
  },
  test2: function() {
    return {};
  }
});
