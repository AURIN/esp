#!/usr/bin/env node

/**
 * Generates CoffeeScript from a UTF-8 CSV containing an ESP Typology schema.
 * @see https://docs.google.com/spreadsheets/d/1Qt5ViQ_II6fYQhwfJicmSMUmTlpUBtnyRbH5CaU1S3g/edit#gid=0
 * @example
 * $ node typology_generator.js <input.csv> [<output.coffee>]
 * $ node typology_generator.js <input.csv> > <output.coffee>
 */

var fs = require('fs'),
    csv = require('csv'),
    _ = require('underscore'),
    js2coffee = require('js2coffee');

var args = process.argv.slice(2);
var inputPath = args[0];
var outputPath = args[1];
if (typeof inputPath !== 'string' || inputPath.length === 0) {
  throw new Error('Invalid CSV path', inputPath);
}

var csvData = fs.readFileSync(inputPath, 'utf8');
// NOTE: CSV is often in win1251 when exported from Excel - transform it to UTF-8 first.
csvData = sanitizeEncoding(csvData);

function sanitizeEncoding(str) {
  // Replace UNICODE dash with ASCII.
  return str.replace(/\u2013|\u8211/g, '-');
}

var nameField = 'Field Name';
var labelField = 'Display Name';
var categoryField = 'Category';
var descField = 'Description';
var unitsField = 'Units';
var typeField = 'Data Type';
var calcField = 'Calculated?';

var integerType = 'Integer';
var floatType = 'Float';
var naNType = 'N/A';
var unitsMap = {
  'm²': 'm^2'
};

function getUnits(units) {
  var result = unitsMap[units];
  if (result === undefined && units !== integerType && units !== floatType &&
      units !== naNType) {
    return units;
  } else {
    return result;
  }
}

csv.parse(csvData, {columns: true}, function(err, output) {
  var categories = {};
  var addToCategory = function(categoryName, fieldName, field) {
    var categoryId = categoryName.toLowerCase().replace(/\s+/, '_');
    var category = categories[categoryId] = categories[categoryId] || {
      label: categoryName,
      items: {}
    };
    var items = category.items;
    if (items[fieldName]) {
      throw new Error('Field "' + fieldName + '" already added to category "' + categoryName +
          '".');
    }
    items[fieldName] = field;
  };
  _.each(output, function(row) {
    var fieldName = row[nameField].trim();
    if (fieldName.length === 0) {
      console.log('Ignoring field with empty name', row);
      return;
    }
    // Sort by category.
    var categoryName = row[categoryField].trim();
    if (categoryName.length === 0) {
      console.log('Ignoring field with no category', row);
      return;
    }

    var field = {};
    var desc = row[descField];
    if (desc) {
      field.desc = desc.trim();
    }
    var label = row[labelField];
    if (label) {
      field.label = label.trim();
    }
    var units = row[unitsField].trim();
    var type = row[typeField].trim();
    var isCalc = row[calcField].trim();

    if (type === floatType || type === integerType) {
      field.type = 'Number';
      if (type === floatType) {
        field.decimal = true;
      }
    } else {
      field.type = 'String';
    }

    units = getUnits(units);
    if (units) {
      field.units = units;
    }

    if (isCalc === 'TRUE') {
      field.calc = '<formula>';
    }

    addToCategory(categoryName, fieldName, field);
  });

  var typologyString = serialize(categories);
  if (outputPath) {
    fs.writeFileSync(outputPath, typologyString);
  } else {
    console.log(typologyString);
  }
});

function serialize(obj) {
  var script = '(' + JSON.stringify(obj) + ')';
  // Remove logging - for some reason js2coffee logs "true".
  var oldLog = console.log;
  console.log = function() {
  };
  script = jsToCoffee(script);
  console.log = oldLog;
  // All types should be names of JavaScript functions.
  return script.replace(/(type\s*:\s*)'(\w+)'/gi, '$1$2');
}

function jsToCoffee(scriptStr) {
  return js2coffee.build(scriptStr, {indent: '  ', single_quotes: true});
}
