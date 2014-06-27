AtlasRenderer = function() {

};
_.extend(AtlasRenderer.prototype, {

  assets: null,
  entities: null,
  atlas: null,
  converter: null,

  startup: function(args) {
    args = _.extend({}, args);
    this.atlas = args.atlas;
    this.assets = {};
    this.entities = {};
    this.converter = new AtlasConverter();
    _.each(args.assets, this.addAsset.bind(this));
  },

  // ADDING

  addAsset: function(asset) {
    var id = asset.id;
    if (!id) {
      id = asset.id = asset.name;
    }
    if (this.assets[id] !== undefined) {
      throw new Error('Asset already added: ' + id);
    }
    this.assets[id] = asset;
    var entities = asset.entities,
        addedEntities = [];
    entities && _.each(entities, function(entity, i) {
      if (typeof entity === 'string') {
        entity = asset.entities[i] = {vertices: entity};
      }
      entity.id = id + '-' + (i + 1);
      entity._asset = asset;
      this.addEntity(entity);
      addedEntities.push(entity);
    }.bind(this));
    asset._origEntities = asset.entities;
    asset.entities = addedEntities;
  },

  addEntity: function(entity) {
    this.entities[entity.id] = entity;
  },

  // ASSETS

  showAsset: function(id) {
    var asset = this.assets[id];
    this._showAsset(asset);
  },

  _showAsset: function(asset) {
    if (asset.entities) {
      this._forEachEntity(asset, this.showEntity);
    } else if (this.isLayer(asset)) {
      this._showLayer(asset);
    }
    // TODO(aramk) Only use camera of asset for assets, just zoom into entity otherwise.
    var camera = asset.camera;
    var position = asset.position;
    if (camera) {
      var elevation = camera.elevation;
      if (elevation !== undefined) {
        position = _.defaults(position, {elevation: elevation});
      }
    }
    this._zoomTo(merge({position: position}, camera));
  },

  hideAsset: function(id) {
    var asset = this.assets[id];
    if (asset.entities) {
      this._forEachEntity(this.assets[id], this.hideEntity);
    } else if (this.isLayer(asset)) {
      this._hideLayer(asset);
    }
  },

  // ENTITIES

  showEntity: function(id) {
    var entity = this.entities[id],
        asset = entity._asset;
    entity = merge({id: id}, asset.defaults, entity);
    this._showEntity(entity);
  },

  _showEntity: function(entity) {
    var id = entity.id;
    var showArg,
        publish = function() {
          console.log('showArg', showArg);
          this.atlas.publish('entity/show', showArg);
        };
    if (!this.atlas._managers.entity.getById(id)) {
      AtlasConverter.ready(function() {
        showArg = this.converter.toGeoEntityArgs(entity);
        publish();
      }.bind(this));
    } else {
      showArg = {id: id};
      publish();
    }
  },

  hideEntity: function(id) {
    this.atlas.publish('entity/hide', {id: id});
  },

  _forEachEntity: function(asset, callback) {
    _.each(asset.entities, function(entity) {
      callback.call(this, entity.id, entity);
    }, this);
  },

  // LAYERS

  _showLayer: function(layer) {
    var czmlUrl = layer.czmlUrl,
        czml = layer.czml;
    // TODO(aramk) Show the layer instead of creating again.
    if (czml && czml.ids) {
      // IDs already set, so we have rendered before. Just show them.
      this.atlas.publish('entity/show/bulk', {
        ids: czml.ids
      });
    } else if (czmlUrl) {
      var czmlAbsUrl = new URI(czmlUrl).absoluteTo(layer._url);
      $.getJSON(czmlAbsUrl.toString(), function(czml) {
        this._showCzml(layer, czml);
      }.bind(this));
    } else if (czml) {
      this._showCzml(layer, czml);
    } else {
      console.error('Unable to show layer', layer);
    }
  },

  _hideLayer: function(layer) {
    var czml = layer.czml;
    if (czml.isImage) {
      // TODO(aramk) Support image layers.
    } else {
      this.atlas.publish('entity/hide/bulk', {
        ids: czml.ids
      });
    }
  },

  isLayer: function(asset) {
    return asset.czmlUrl !== undefined || asset.czml !== undefined;
  },

  // CZML

  _showCzml: function(layer, czml) {
    var isImage = czml.isImage,
        content = JSON.parse(czml.content);
    czml = layer.czml = {
      isImage: isImage,
      content: content
    };
    if (czml.isImage) {
      // TODO(aramk) Support image layers.
    } else {
      this.atlas.publish('entity/show/bulk', {
        features: content,
        callback: function(ids) {
          czml.ids = ids;
        }
      });
    }
  },

  // CAMERA

  _zoomTo: function(args) {
    this.atlas.publish('camera/zoomTo', args);
  },

});
