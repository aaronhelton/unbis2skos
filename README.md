unbis2skos
==========

Converts UNBIS Thesaurus SDF files to SKOS Core

status: complete

skosify.rb transforms structured data from a Lotus Notes database into SKOS-compliant output of a variety of formats. It reads the SDF file consisting of key value pairs, splits it into temp files, then parses into individual members of class skos:Concept before outputting to a desired format. Categorization is handled by registering a set of  EuroVoc Domain classes, assigning to each Domain a set of EuroVoc MicroThesaurus members, then assigning to each MicroThesaurus members of skos:Concept.

Output options include single and split files (one ConceptScheme, Domain, MicroThesaurus, or Concept per file), and whether to treat labels as regular SKOS Core labels or SKOS-XL labels.

Run with -h to list the flags and options available.

The output has been narrowed down to RDF Terse Triple Language (Turtle) because there are other tools available for converting to different formats, and they do so more predictably. For instance, Python's RDFLib package provides very handy tools for navigating and serializing the data in different formats, including RDF/XML and JSON-LD. Further, the data output is readily ingestible into triple store software such as Jena, Sesame, Virtuoso, and others.

==========

Because of UN intellectual property concerns, a full SDF file is not included with this repository.  An extract suitable for use with the tools here is available by request via the contact links on the UNBIS Thesaurus website: http://lib-thesaurus.un.org/LIB/DHLUNBISThesaurus.nsf

Similarly, requests for SKOS formatted XML extracts of the Thesaurus should go through the same contact method.
