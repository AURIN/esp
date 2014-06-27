var HomeController = RouteController.extend({
  template: 'home'
});

Router.map(function () {
  this.route('home', {
    path :  '/home',
    controller :  HomeController
  });
});
