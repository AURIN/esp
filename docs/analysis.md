# Analysis

ESP uses an original analysis model developed from wide and extensive research.

## Typologies

A **typology** is a blueprint for a specific building, use of open space, or other land use. Each
typology has a **class** and a **subclass** (in parentheses below), which is one of:

* Residential (Single House, Attached House, Walkup, High Rise)
* Commercial (Retail, Office, Hotel, Supermarket, Restaurant)
* Institutional (School, Tertiary, Hospital, Public)
* Mixed Use (no subclasses)
* Open Space (no subclasses)
* Pathway (Freeway, Highway, Street, Footpath, Bicycle Path)

The class and subclass determine the set of parameters that apply to the typology. Each typology
will then provide its own set of values for those parameters.


## Entities

If a typology is a blueprint of a land use, then an **entity** is an *instance* of a typology.
Multiple entities can (and typically will) be created from the same typology. The reports for your
project are compiled from the sum of the *entities* in the project; the typologies alone don't
count.


## Lots

An entity can only be placed on a **lot**. A lot is simply a polygon, but usually represents a
cadastre. Lots are simple, but serve a handful of purposes:

* The lot area is calculated automatically, and is a key input into the analysis.
* A lot has a *class* (essentially the *zoning* of the lot), which restricts which typologies can be
  built on it. This is displayed as the *colour* of the lot.
* A lot has an *allowable height* property taken from the local building codes that also restricts
  which typologies can be built on the lot. This can be displayed by extruding the *height* of the
  lot polygons.
* A lot can be *developable* ("for development") or not. Typologies can only be placed on
  developable lots. This is displayed in the *saturation* of the lot colour (darker lots are
  developable).


## Reports

The performance of a precinct design is forecast by the analysis model and summarised in a
**report**. Reports are selected and displayed in the right sidebar.

* There is a report for each *class* of typologies, which will include in the calculation only
  entities with typologies in that class.
* There is also a *precinct* report that will aggregate *all* of the entities in the project.

With either report displayed, you can select one or more entities on the map to generate a
*selective* report. The report will aggregate only the entities that you selected. Deselect all
entities to return to the overall reports.


## References

TODO: List of relevant papers.
