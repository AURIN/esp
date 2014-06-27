var AtlasController = RouteController.extend({
  template: 'atlas'
});

Router.map(function () {
  this.route('atlas', {
    path :  '/',
    controller :  AtlasController
  });
});
