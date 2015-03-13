unbis2skos
==========

Converts UNBIS Thesaurus SDF files to SKOS Core

skosify.rb transforms structured data from a Lotus Notes database into SKOS-compliant output of a variety of formats. It reads the SDF file consisting of key value pairs, splits it into temp files, then parses into individual members of class skos:Concept before outputting to a desired format. Categorization is handled by registering a skos:ConceptScheme, assigning to it members of class eu:Domain, assigning to each eu:Domain a set of members of class eu:MicroThesaurus, then assigning to each eu:MicroThesaurus members of skos:Concept via a skos:hasTopConcept relationship. 

Output options include single and split files (one ConceptScheme, Domain, MicroThesaurus, or Concept per file), RDF/XML, basic JSON, nTriples, Turtle, and Rails-formatted ActiveRecord SQL (for use with https://github.com/aaronhelton/vocs ). 

Run with -h to list the flags and options available.

To do:

1.  Complete output formatting for Domain and MicroThesaurus
2.  Fix skos:Collection handling, which caused issues in to_rails output, but probably needs to be present to comply with SKOS-Core
3.  Add JSON-LD output 
4.  Add owl:SameAs entries to preserve links to the existing non-SKOS thesaurus website

One particular use of this output, formatted via https://github.com/aaronhelton/unbis-dart, is visible here: http://unbis-thesaurus.s3-website-us-east-1.amazonaws.com/

==========

Because of UN intellectual property concerns, a full SDF file is not included with this repository.  An extract suitable for use with the tools here is available by request via the contact links on the UNBIS Thesaurus website: http://lib-thesaurus.un.org/LIB/DHLUNBISThesaurus.nsf

Similarly, requests for SKOS formatted XML extracts of the Thesaurus should go through the same contact method.
