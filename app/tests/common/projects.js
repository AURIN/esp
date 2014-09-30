var assert = require('assert');

suite('ProjectUtils', function() {

  test('toJson', function(done, server) {
    server.eval(function() {
      var projectId = Projects.insert({
        name: 'Foo',
        parameters: {
          general: {
            creator: 'me'
          },
          location: {
            country: 'Australia',
            ste_reg: 'Victoria',
            loc_auth: 'Melbourne City'
          }
        }
      });
      var typologyId = Typologies.insert({
        name: 'Residential',
        project: projectId,
        parameters: {
          general: {
            'class': 'RESIDENTIAL'
          }
        }
      });

      var json = ProjectUtils.toJson(projectId);

      var expectedProject = Projects.findOne(projectId);
      expectedProject.name = 'Foo 2';
      var expected = {
        projects: [expectedProject],
        typologies: [Typologies.findOne(typologyId)],
        entities: [],
        lots: []
      };

      emit('result', {
        json: json,
        expected: expected
      });
    }).once('result', function(result) {
      assert.deepEqual(result.json, result.expected);
      done();
    });
  });

  test('fromJson', function(done, server) {
    server.eval(function() {
      var projectId = Projects.insert({
        name: 'Foo',
        parameters: {
          general: {
            creator: 'me'
          },
          location: {
            country: 'Australia',
            ste_reg: 'Victoria',
            loc_auth: 'Melbourne City'
          }
        }
      });
      var typologyId = Typologies.insert({
        name: 'Residential',
        project: projectId,
        parameters: {
          general: {
            'class': 'RESIDENTIAL'
          }
        }
      });

      var json = ProjectUtils.toJson(projectId);

      console.log('json', json);

      function createModelMaps(idMaps, useNewIds) {
        useNewIds = useNewIds !== undefined ? useNewIds : true;
        var modelMaps = {};
        var collectionMap = Collections.getMap([Projects, Entities, Typologies,
          Lots]);
        _.each(idMaps, function(idMap, name) {
          var collection = collectionMap[name];
          var modelMap = modelMaps[name] = {};
          _.each(idMap, function(newId, oldId) {
            var id = useNewIds ? newId : oldId;
            modelMap[id] = collection.findOne(id);
          });
        });
        return modelMaps;
      }

      ProjectUtils.fromJson(json).then(Meteor.bindEnvironment(function(idMaps) {
        console.log('idMaps', idMaps);
        var oldModelMaps = createModelMaps(idMaps, false);
        var newModelMaps = createModelMaps(idMaps, true);
        console.log('newModelMaps', newModelMaps);
        console.log('oldModelMaps', oldModelMaps);
        emit('result', {
          json: json,
          projectId: projectId,
          typologyId: typologyId,
          idMaps: idMaps,
          oldModelMaps: oldModelMaps,
          newModelMaps: newModelMaps
        });
      }));
    }).once('result', function(result) {
      var idMaps = result.idMaps;
      var oldModelMaps = result.oldModelMaps;
      var newModelMaps = result.newModelMaps;
      var projectMap = idMaps.projects;
      var entityMap = idMaps.entities;
      var typologyMap = idMaps.typologies;
      var lotMap = idMaps.lots;

      assert.equal(Object.keys(typologyMap).length, 1);
      assert.equal(Object.keys(projectMap).length, 1);
      assert.equal(Object.keys(entityMap).length, 0);
      assert.equal(Object.keys(lotMap).length, 0);

      var oldProjectId = result.projectId;
      var newProjectId = projectMap[oldProjectId];
      var oldProject = oldModelMaps.projects[oldProjectId];
      var newProject = newModelMaps.projects[newProjectId];
      assert.notEqual(oldProjectId, newProjectId);
      assert.equal(newProject.name, "Foo 2");
      assert.deepEqual(newProject.parameters, oldProject.parameters);

      var oldTypologyId = result.typologyId;
      var newTypologyId = typologyMap[oldTypologyId];
      var oldTypology = oldModelMaps.typologies[oldTypologyId];
      var newTypology = newModelMaps.typologies[newTypologyId];
      assert.notEqual(oldTypologyId, newTypologyId);
      assert.equal(newTypology.project, newProjectId);
      assert.equal(newTypology.name, oldTypology.name);
      assert.deepEqual(newTypology.parameters, oldTypology.parameters);

      done();
    });
  });

});
