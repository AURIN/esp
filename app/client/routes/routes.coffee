MainController ->
  RouteController.extend
    template: 'main'

Router.map ->
  this.route 'main', {
    path: '/',
    controller: MainController
  }
