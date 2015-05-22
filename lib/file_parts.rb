$xml_header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rdf:RDF
  xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\"
  xmlns:owl=\"http://www.w3.org/2002/07/owl#\"
  xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"
  xmlns:skos=\"http://www.w3.org/2004/02/skos/core#\"
  xmlns:dc=\"http://purl.org/dc/elements/1.1/\"
  xmlns:xsd=\"http://www.w3.org/2001/XMLSchema#\">"
$xml_footer = "</rdf:RDF>"

$turtle_header = "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@base <#{$base_uri}> .

"