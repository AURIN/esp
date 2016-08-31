# ESP typologies

## Each typology has three main files

* A shape file of the building footprint, typically with the state and climate code as the first identifier of the file: state_typology. shp
* An xml file containing the 3D image of the typology, transformed to a Collada file and packaged to display in a 3D world. Also typically with the state and climate code it was assessed in: state_typology.xml
* The set of data that needs to be manually entered into ESP: typology.xlsx. These have been supplied in both basic (typical construction materials) and advanced (more sustainable construction materials) for certain typologies.

## ESP has the following base residential typologies

* Attached house
* Separate house
* Walk-up apartments (no lift)
* High rise apartments 

Non-residential typologies include COM (commercial, INS (institutional) and  MIX (mixed use) all of which are auto-populated based on the unloaded footprint of building. Roads, paths and open space are also assessed dynamically in the system, once created.  

## ESP typologies use the following nomenclature: 

Dwelling type\_Stories\_Bedrooms\_Dwellings\_Effeciency level 

* SH 1st 3b basic = Separate house 1 story, 3 bedroom, basic
* SH 2st 4b basic = Separate house 2 story, 4 bedroom, basic
* AH 1st 2b basic 6 plex = Attached house, 1 story, 2 bed, basic, 6plex (terrace of 6)  
* AH 2 st 2b basic 6 plex = Attached house, 1 story, 2 bed, basic, 6plex (terrace of 6)
* GH 1st 3b basic 2 plex = Grouped house, 1 story, 2 bed, basic 2plex (terrace of 2)
* HR 5st 1&2b basic 40dw = High rise 1 and 2 bedroom, basic, 40 dwellings 
* WU 2st 1b basic 8dw = Walkup, 2 story, 1bedroom, basic, 8 dwellings

The supplied typologies are those that have been assessed in Western Australia, as this is the location of the supplied tutorial. New assessments will need to occur for projects occurring in areas outside of Western Australia. 

# Starting a new typology

At any point in time during the precinct design process, users can click on the + icon in the Typologies panel on the left to submit a new typology to the list/library. A user will encounter the Typology Creation Form allowing a name, description and land use class to be specified for the new typology. Once a land use class has been selected from the list, the form will expand to show the class-specific fields that need to be populated to define the new typology.

# Spatial data for typologies

# Building footprints

At a minimum, users are required to provide a 2D building footprint to represent any precinct typology that is not of the Open Space or Pathway class. As such, if this is not provided then the form will not allow a user to save their new typology and submit it to the library. Most GIS applications support the drawing and creation of 2D data that can be used to create typology footprint data for uploading to ESP. The software used in preparing the library for the template projects was MapInfo. When creating a typology footprint to import into ESP, the following points must be kept in mind:
* Footprints must be drawn to scale, so use a projected coordinate system when drawing them or make sure your measurements are metric.
* The front door/entry of the building is assumed to be south facing.
* The location of the drawn footprint can be anywhere in the world. The coordinates of the receiving lot replace the coordinates of the footprint when the typology is placed in a precinct.
* Footprints must be saved as Shapefiles in the EPSG 4326 coordinate referencing system.
* All files associated with the Shapefile must be zipped together and given the “.zip” extension. Do not zip a folder containing the files (i.e. zip the files together directly), otherwise will the file will not upload.
* Try to adopt a consistent naming convention. For the default building library the following convention for residential typologies was chosen: [state]_[climate zone]_[subclass]_[storeys]_[bedrooms]_[type]. The chosen convention applied to a single storey 3 bedroom single house in Western Australia looks like this: WA_CZ13_SH_1St_3Bed_Basic.
* To upload a zipped Shapefile, simply click the “Choose File” button under the 2D Geometry heading in the Typology Creation Form and navigate to the desired file.

# 3D meshes

When creating a new typology in ESP, users can optionally include a 3D mesh of their typology for more detailed visualisation in the system. When creating a 3D mesh for import into ESP, the following points must be kept in mind
* Any 3D drawing software suite can be used, however the final file must be saved as a COLLADA file (i.e. the “.dae” extension). Google SketchUp is an option that is effective for this purpose and can be downloaded for free.
* Meshes must be drawn to scale and ideally have a footprint that is identical to the 2D footprint supplied along with the mesh. ESP does not have validation to ensure that the mesh and footprint match.
* As with the building footprint, the front of the building is assumed to be south facing.
* Colours and textures may be added to the mesh for styling.
* The number of vertices does not matter; however, note that simpler meshes (fewer vertices) will render more quickly and easily in the system and allow more objects to be visualised simultaneously. This will be more of an issue with larger precincts containing several hundred or thousand objects.
* Once a COLLADA file is prepared representing the typology, users must create a KMZ file that includes the COLLADA file before uploading it to ESP. A KMZ file is a zipped file given the “.kmz” extension that contains a “doc.kml” file and a “mesh” folder containing the COLLADA file. Just ensure that the name of the mesh file (indicated in bold in the example KML) is replaced with the appropriate name chosen for the typology. The coordinates of the mesh are inconsequential as ESP translates them when the typology is eventually placed in the precinct.
* When naming the mesh, user the same name as applied to the typology footprint.
* The “doc.kml” file and the “mesh” folder containing the COLLADA file should be zipped together directly and not put in another folder first. Once the KML and the “mesh” folder have been zipped together, the resulting file should be renamed with the appropriate name for the typology and given the “.kmz” extension (i.e. not the “.zip” extension).

Note: Users can test whether their building model/mesh renders properly in Google Earth before importing it into ESP. If it renders in Google Earth, it should render in ESP.

To upload a KMZ file containing the building mesh, simply click the “Choose File” button under the 3D Geometry heading in the Typology Creation Form and navigate to the desired file.

# Residential typologies

The Residential typology class is the only class in ESP that expects its typologies to be partially assessed using third party software. The assessment software used when preparing the default residential typology library was AccuRate Sustainability, a fully featured software package developed by CSIRO for rating the energy efficiency of residential building designs. AccuRate was used as it provides the standard for the Nationwide Housing Energy Rating Schema (NatHERS) in Australia.

While the Residential Typology Creation Form expects inputs that are outputs from an AccuRate assessment summary report, users are free to provide values derived from other sources. One benefit of using AccuRate, however, is that assessments can be done for various azimuth rotations of a building to test how aspect and ventilation impact heating and cooling energy demand. For the default library, assessments were carried out for all 45 degree rotations from 0 to 360 degrees, allowing heating and cooling energy demand values to change as buildings are rotated on a site.

While some attributes of a property’s performance can be assessed on the basis of the building typology itself, other property attributes cannot be determined until the size of the parent lot is known. As such, ESP models several residential typology attributes pertaining to external land internally by making use of default coefficients that can be overridden by users. ESP also models some building performance attributes internally by giving users control over heating and cooling appliance efficiency, the energy derived from PVs, stove and oven type, appliance fit-out, capital and operating costs, and parking.

Most of the Residential Typology Creation Form’s fields are self-explanatory; however, a few could use some further explanation. This information can be found below:
* Gross Floor Area (GFA) vs. Conditioned Floor Area (CFA): For the Residential class, ESP uses GFA in the calculation of planning metrics like plot ratio. CFA only accounts for the spaces in a residence that are heated and cooled. As such, usually the garage and laundry areas are omitted from a CFA calculation. CFA is used to calculate heating and cooling energy demands in ESP when the user provides heating and cooling energy arrays
* Proportion Extra Land: As the size of a property’s lot, and hence its extra land, is unknown until a building typology is placed on a lot, these proportions are used to determine the amount of external land allocated to various surface types. These proportions impact things like stormwater, landscaping costs, external embodied carbon, irrigation demand, and non-garage parking on the lot. Users may wish to increase the proportion allocated to impermeable surfaces if the residential subclass is walkup or apartment and the majority of parking is expected to ground-level and on the property.
* Orientation: The default orientation of a building in ESP is 0 degrees with the front of a building being south facing. This is how a residential typology should be assessed in AccuRate and drawn. If this value is not overridden then a building placed in a precinct will auto-orientate itself to be street facing. If the azimuth is overridden then a building will always initially render with the provided orientation.
* Heating and Cooling Energy Arrays: Use of these arrays is optional. If users wish to use the per square metre heating and cooling values from an AccuRate assessment then they can be provided here and rotating a building will consequently impact its heating and cooling energy requirements. Inputting values for these arrays will hide the Heating and Cooling fields in the form. If even a single value of an array is left blank, the system will expect a Heating or Cooling value to be provided instead. This was done to make the system amenable to being used by users without access to the AccuRate software. IfHeating and Cooling values are provided instead, rotating a building will have no effect on its heating and cooling calculations. Note, these values represent the thermal heating and cooling energy requirements for space conditioning, not the energy required to operate the heating and cooling appliances that are calculated internally using the COP and EER values.
* PV System Size: ESP models the effects of PV systems on buildings internally by allowing users to select the PV system size (default is 0 kW). As such, PVs should be excluded from AccuRate assessments. Users can change the default PV system size from 0 to any value they wish for modelling purposes.
* Water Demand: Once users have provided a water use intensity value (kL/occupant/year) for the typology they are creating, they have the option to add a rainwater capture system and greywater recycling system. Rainwater supply, if checked, is calculated based on average annual rainfall, roof area and a rainwater capture efficiency value, while grey water supply is calculated based on a percentage of internal water use that is being expelled as greywater. It is assumed that rainwater can be used internally and externally while greywater is only used externally.
* Building Type and Cost: Users who know the construction cost of their typology are free to provide this value directly into the form. In most cases, however, it is expected that construction cost will be unknown so users are given the option of selecting a build quality type from the dropdown menu and a cost will be calculated internally based on GFA and the typology subclass.
* Underground Parking: Specifying the number of underground parking spaces has three outcomes. First, it adds to the number of parking spaces available. Second, it factors the construction of these underground bays into the construction cost calculations. Third, it adds the embodied carbon of the parking space to the embodied carbon calculations.
* Parking Land Ratio: This ratio specifies how much of the impermeable extra land surfaces are available for parking

# Commercial and institutional typologies
Unlike the Residential typology class, the Commercial and Institutional class typologies are assessed entirely within ESP using default parameters that can be overridden by the user. The reason for this is that AccuRate is only for residential buildings. While the level of detail behind the commercial and institutional assessments is not as great as in the residential class, which is the focus of ESP and middle suburb redevelopment, the benefit of this simpler assessment model is that it is much faster to prepare new commercial or institutional typologies and no other software is required. Also, the parameters used for the assessment calculations can be found with relative ease by scanning widely available reports, journal articles and papers.

Once either the Commercial or Institutional class has been selected in the Typology Creation Form, many of the fields that render will look similar to those in the Residential class form. One new field, however, is the Job Intensity field that contains a parameter used for calculating the number of jobs that will be generated by the building. Users will also see electricity use, gas use and internal embodied carbon intensity fields replacing the direct input fields in the Residential class form. These parameters are used to calculate electricity use, gas use and internal embodied carbon respectively when multiplied by the building’s GFA. When a user selects a subclass from the dropdown menu then default values will automatically be populated for the subclass specified. This means that once an appropriate subclass is selected, all users have to do is provide the geometry data for the typology and their new commercial or institutional typology is nearly complete. The final field to consider is the Build Type field in the Financial section of the form that will automatically filter down once a subclass is selected, allowing subsets of that typology subclass to automatically be costed or users to specify their own costing if the Custom option is selected.

Users should note that the default Proportion Extra Land parameter values differ from those in the Residential section. This is because it is typical of commercial and institutional buildings that the majority of extra land is impermeable and allocated to street-level parking. The amount of impermeable extra land available for parking can be adjusted by changing the Parking Land Ratio parameter as with the Residential class.

# Mixed use typologies

The Typology Creation Form for the Mixed Use class is somewhat of a hybrid between the forms for the Residential class and the Commercial and Institutional classes. Like the Commercial and Institutional classes, assessment is carried out entirely within ESP but a few extra fields are present to account for the residential component. These include fields reporting the number of dwellings of varying bedroom numbers and the number of occupants expected to be housed. Also, since it can be expected that electricity use, gas use, and water use intensities will differ between residential and commercial spaces, separate intensity fields exist for the two components and well as separate fields for reporting GFA.

# Open space typologies

The Open Space class is the simplest of all of ESP’s typology classes to define new typologies for. There is no 2D footprint or 3D mesh to upload for this typology class. Instead a textured pattern will render on a lot once a typology of this class is placed in a precinct. An open space typology is essentially defined the same as extra land for typologies that have buildings associated with them. Users simply provide the proportion of land allocated to each of the four surface types: lawn, annual plants, hardy plants and impermeable surfaces. Note that edible plants will fall under the category of “annual plants”, however food production is not calculated in ESP due to the extreme variability of this reporting metric that depends on rainfall, soil conditions, and more.

# Pathway typologies

The Pathway typology class can be deemed the most different of all the classes in the way that a new typology is defined. A pathway can be anything from an eight-lane freeway to a simple pedestrian footpath that meanders through a subdivision. Users define a new typology of this class by specifying the number of lanes and the width of each lane for each of the cross-sectional elements. The cross-sectional elements available for users to choose from include the following: road lanes, parking lanes, footpath lanes, bicycle lanes, and verges. For each cross-sectional element, users are also able to specify a construction profile that is used to determine the construction cost and embodied carbon of the pathway being defined.

As with the Open Space class, no 2D or 3D geometry data needs to be uploaded when creating a new typology of this class. ESP handles the geometry creation of a pathway object when users draw it into a precinct. The number of lanes and width of each lane of each cross-sectional element as defined in the typology determine the width of a pathway being drawn, while a pathway’s length is determined as user draws it into a precinct. Once a pathway is drawn, its length is used internally in ESP to calculate the area of each surface type as well as a variety of other reporting attributes like stormwater runoff and embodied carbon.
