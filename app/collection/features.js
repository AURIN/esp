Features = new Meteor.Collection('features');
function allow() {
  return true;
}
Features.allow({
  insert: allow,
  update: allow,
  remove: allow
});
