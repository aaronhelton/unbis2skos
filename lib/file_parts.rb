$xml_header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rdf:RDF
  xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\"
  xmlns:owl=\"http://www.w3.org/2002/07/owl#\"
  xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"
  xmlns:skos=\"http://www.w3.org/2004/02/skos/core#\"
  xmlns:dc=\"http://purl.org/dc/elements/1.1/\"
  xmlns:xsd=\"http://www.w3.org/2001/XMLSchema#\"
  xmlns:unbist=\"http://replaceme/\">\n"
$xml_footer = "</rdf:RDF>"

$turtle_header_old = "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix unbist<#{$base_uri}> .

"
$turtle_header = "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n@prefix skos: <http://www.w3.org/2004/02/skos/core#> .\n@prefix skosxl: <http://www.w3.org/2008/05/skos-xl#> .\n@prefix eu: <http://eurovoc.europa.eu/schema#> .\n@prefix unbist: <http://replaceme/> .\n"