# Catalogue of Life Mobile
Present the most comprehensive, global taxonomy using native swift tabs at the bottom.

## data
Retrieve data from the checklistbank.org API.
This requires knowing the dataset key of the current / latest version.
It can be discovered by doing /dataset/3LXR for the extended release.
In addition to the latest extended release COL also provides annual releases and a "base release" accessible via /dataset/3LR.
Allow the user to select the version they are looking at.


## tab1 - the tree
offer a tree browser using the tree API.
Place a quick suggest entry at the top to jump to the tree for that name.
allow to open a taxon details screen (see below)

## tab2 - search
search names and present tabular result.
link to a taxon details screen for the accepted taxon.

### taxon details page
synonyms should resolve to the accepted name, there are no pure synonym pages.
show the entire /info information.
Link to catalogueoflife for the latest release and to checklistbank for the annual older releases.
Visualize the synonymy nicely using 
Taxonomic breakdown sunburst diagram
Integrate a GBIF data section:
 - metrics
 - show small map
 - image carousel

## tab3 - sources
list all sources with logo and show source detail with all metrics

## tab4 - metrics
dataset taxonomic sunburst breakdown
show the dataset "import" metrics

## tab5 - about COL
Explain what COL is, how identifiers work.
All release metadata (changes when selecting other releases)
