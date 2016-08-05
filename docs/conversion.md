# Conversion

ESP uses the [AURIN Asset Conversion Service](https://github.com/AURIN/acs) to convert all user provided assets into data it can consume.

## Sources

### Lots

When creating a project, a zipped Shapefile containing the geometry and properties of the subdivided precinct is uploaded by the user.

### Typologies

Users must associate 2D Shapefile geometry representing the footprint of each Typology created. Objects inherit this footprint when they are instantiated within the precinct from the Typology. A detailed 3D KMZ mesh can also be associated with the Typology.

## Workflow

In order to convert the input geometry and convert it to a readable format, ESP performs the following steps:

### Upload

The file is uploaded from the user's browser to the server.

### Storage

* In production, the file data is stored in an S3 bucket.
* When run locally, the data is stored on the filesystem in .meteor/local/cfs.
* The storage location is hidden by adapters from the rest of the application layer which deals only in abstract file data.
* Importing Lots does not store the data. The byte data is parsed in memory and sent for conversion.

### Conversion

The data is sent to the Asset Conversion Service for conversion into C3ML, a JSON format readable by Atlas for rendering.

### Representation

Lots are created from the imported geometry and the C3ML data is stored directly on the MongoDB documents.

Typology geometry is stored as C3ML JSON files and their reference is stored in place of the actual data. The renderer downloads the data in these files at runtime. This is to reduce the amount of data stored and retrieved, since typologies are used as templates for creating objects. When rendering objects of the same typology, the geometry data only needs to be downloaded once since it's shared across all objects of that typology.
