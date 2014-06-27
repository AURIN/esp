Router.configure({
  layoutTemplate: 'atlasLayout',
  notFoundTemplate: 'notFound',
  yieldTemplates: {
    'header': { to: 'header' },
    'footer': { to: 'footer' }
  }
});