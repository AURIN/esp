#!/usr/bin/env node

/**
 * Generates a list of parameters form a CoffeeScript file containing a typology object.
 * @example
 * $ node typology_param_extractor.js <input.coffee> [<output>]
 * $ node typology_param_extractor.js <input.coffee> > <output>
 */

var fs = require('fs'),
    _ = require('underscore'),
    coffee = require('coffee-script');

var args = process.argv.slice(2);
var inputPath = args[0];
var outputPath = args[1];
if (typeof inputPath !== 'string' || inputPath.length === 0) {
  throw new Error('Invalid CSV path', inputPath);
}

var inputScript = fs.readFileSync(inputPath, 'utf8');
inputScript = 'Units = {};' + inputScript;
var schema = coffeeToJs(inputScript);
var params = getSchemaParams(schema);
var paramList = params.join('\r\n');
if (outputPath) {
  fs.writeFileSync(outputPath, paramList);
} else {
  console.log(paramList);
}

function getSchemaParams(schema) {
  return schemaFields({items: schema});
}

function schemaFields(schema) {
  var fields = [];
  _.each(schema.items, function (field, fieldId) {
    if (field.items) {
      var subFields = schemaFields(field);
      _.each(subFields, function (subFieldId) {
        fields.push(fieldId + '.' + subFieldId);
      });
    } else {
      fields.push(fieldId);
    }
  });
  return fields;
}

function coffeeToJs(coffeeStr) {
  return coffee.eval(coffeeStr);
}
