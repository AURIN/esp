# Conversion

ESP uses the [AURIN Asset Conversion Service](https://github.com/AURIN/acs) to convert all user provided assets into data it can consume.

## Sources

### Lots

When creating a project, a zipped Shapefile containing the geometry and properties of the subdivided precinct is uploaded by the user.

### Typologies

Users must associate 2D Shapefile geometry representing the footprint of each Typology created. Objects inherit this footprint when they are instantiated within the precinct from the Typology. A detailed 3D KMZ mesh can also be associated with the Typology.

## Workflow

In order to convert the input geometry and convert it to a readable format, ESP performs the following steps:

* Upload - the file is uploaded from the user's browser to the server.
* S3 storage - in production, the file data is stored in an S3 bucket. When run locally, the default behaviour is to store it on the filesystem. This information is hidden and irrelevant to the rest of the application layer which deals only in abstract file data.
* TODO

