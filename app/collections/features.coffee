# TODO(aramk) Remove in favour of Entities eventually once rendering has been migrated.
@Features = new Meteor.Collection('features')
Features.allow(Collections.allowAll())
