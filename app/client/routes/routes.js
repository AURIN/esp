var MainController = RouteController.extend({
  template: 'main'
});

Router.map(function () {
  this.route('main', {
    path :  '/',
    controller :  MainController
  });
});
