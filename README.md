# MARC bibliographic record to RDF converter

    MARC2RDF - a ruby toolkit to convert bibliographic MARC to RDF by YAML mapping
    Copyright (C) 2012 Benjamin Rokseth
    Purpose: Convert binary/xml marc to semantic markup using yaml mapping file
             Import into RDF triplestore and maintain via OAI-PMH harvesting

## GPLv3 LICENSE
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>."

## FEATURES

The toolkit consists of three parts:

* marc2rdf.rb      -- a ruby script to convert binary MARC records to RDF (ntriples, turtle or rdf/xml)
* oai_harvester.rb -- a ruby script (cronjob) to harvest and convert MARC records from an OAI_PMH repository 
and update a RDF triplestore
* harvester.rb     -- a ruby script to harvest bibliographical metadata via SPARQL or XML APIs,
and convert to semantic triples (RDF) and optionally import to existing RDF store

Auxiliary tool to fix input file

* marcfix.pl strips erroneous 000 tags from binary MARC records in iput file

## HOWTO

### REQUIREMENTS

Ruby

* ruby >= 1.8.7
* ruby-marc (thanks to Ross Singer et.al.)
* rdf.rb (thanks to Arto Bendiken et.al. for the brilliant RDF library for ruby)
* rdf-rdfxml.rb (requires development libraries libxml2 and libxslt1)
* rdf-virtuoso
* rest-client (if not using Virtuoso as storage)
* oai

Requirements for marcfix.pl

 * Perl
 * MARC::Record perl module from [CPAN](http://search.cpan.org/~gmcharlt/MARC-Record-2.0.3/lib/MARC/Record.pm)

### INSTALL

Here is a short walk-trough on how to install the needed tools and libraries.

1. Clone this repository form github  
	* ```git://github.com/digibib/marc2rdf.git```  
	This creates a subdirectory called marc2rdf

1. Either install ruby via rvm (Ruby Version Manager) or install ruby-dev  
	*  Ubuntu install (for ruby and rdf-xml support)  
	```sudo apt-get install ruby-dev libxml2-dev libxslt1-dev libyaml-ruby libzlib-ruby rubygems```  
	* Debian note  
	Debian adds a version postfix to the ruby executables. Thus all references to `ruby` becomes 
	`ruby1.8` and references to `gem` becomes `gem1.8`.

1. Install RubyGems bundler  
	```sudo gem install bundler```  
	If you can not or do not want to install RubyGems into system folder locations, please have a look at 
	http://docs.rubygems.org/read/chapter/3/

1. Install needed gems given in Gemfile:  
	```
	cd marc2rdf
	bundle install
	```

1. Copy needed configuration files  
	```
	cp ./config/config.yml-dist ./config/config.yml
	cp ./config/harvesting.yml-dist ./config/harvesting.yml
	```  
	* Make changes to the new files as needed to fit your system.  
	* Please read rspec tests under ./spec for examples on usage.  

1. Install Perl and MARC::Record  
	On Debian and Ubuntu these are installed with apt:  
	```
	apt-get install perl libmarc-record-perl
	```  
	MARC::Record can also be installed with 
	[CPAN](http://search.cpan.org/~gmcharlt/MARC-Record-2.0.3/lib/MARC/Record.pm)  

### RDF STORE

 * Recommended triplestore is OpenLink Virtuoso, minimum version 6.1.3
 * any other triplestore should work fine, though, as long as it supports SPARQL 1.1 UPDATE LANGUAGE

#### Ubuntu

```
sudo apt-get install virtuoso-opensource
```

#### Debian

Debian squeeze does not have a recent version of Virtuoso. Please compile from source as described 
over at [their site](http://virtuoso.openlinksw.com/dataspace/dav/wiki/Main/VOSDebianNotes). 

Debian wheezy comes with Virtuoso version 6.1.4, as does Ubuntu 12.04 Precise.

### PREPARATION

Command line options are listed by running either of the three Ruby scripts.

A typical conversion consists of:

* converting an entire MARC binary record set with marc2rdf.rb.
* splitting up and importing result RDF to a triplestore
* setting up cron job to use OAI-PMH repository with oai_harvester.rb
* adding sources to harvest and reap the internet with harvester.rb

Before conversion, care must be taken to setup config files under ./config

Three config files are needed:

* config.yml (file and RDF repository settings)
* harvesting.yml (sources and settings for harvesting)
* mappingfile.yml (MARC to RDF mapping)

examples on all three are under ./config 

Excerpt of YAML mapping given below.

For full list of functions see example YAML file 'config/mapping-normarc2rdf.yml' based on NORMARC variant of USMARC

* tag numbers can be regex (e.g. "^5(?!71)" for 500-599 minus 571)
* predicates are given in format PREFIX.suffix and non-standard prefixes must exist in ./lib/rdfmodeler.rb
* objects prefixes must be exploded 
* predicates can be conditionally mapped from subfields or indicators
* objects can have language tags given as symbols (:se, :en_UK etc)
* objects can be mapped key => values
* relations can have subfields
* string replace non-ascii characters to create uris
* oai harvester uses same mapping as marc2rdf given in config.yml
* erroneous 000 marc field in normarc can be removed with perl script ./tools/marcfix.pl

## FILES INCLUDED

* marc2rdf.rb                            -- main ruby script to convert NORMARC file to RDF
* oai.rb								 -- oai harvester skript to harvest and update rdf store
* lib/
    * string_replace.rb                  -- mapping of UTF8-encoded characters
    * rdfmodeler.rb                      -- the MARC to RDF conversion module
    * sparql_update.rb                   -- SPARQL Update module
* config/
    * config-dist.yml                    -- config file
    * mapping-normarc2rdf.yml            -- example mapping file: NORMARC tags to rdf mapping
    * mapping-normarc2rdf-with-authorities.yml  -- example mapping file: NORMARC tags to rdf mapping with authorities    
    * mapping-normarc2rdf_bildebaser.yml -- example mapping file: image base in NORMARC
* hamsun_fikset.mrc                      -- test NORMARC file
* output.rdf                             -- test output RDF with -r 50 (50 records)

## YAML MAPPING

uses yaml hashes mapping. Example excerpt:

    tag:
      '700':
        subfield: 
          a:
            conditions:
              subfield:
                e:
                  orig: 'arr|bearb|biogr|dir|fort|foto|...|utøv'
                  subs: 
                    arr: DEICHMAN.musicalArranger
                    bearb: DC.contributor
                    biogr: DEICHMAN.biographer
                    dir: DEICHMAN.director
                    eks: DEICHMAN.performer
                    forf: DC.creator
                    fort: DC.narrator
                    foto: DEICHMAN.photographer
                    ...
                    utøv: DEICHMAN.performer
                  default: DC.contributor
            object:
              combine:
                - a
                - b
                - d
              combinestring: '_' 
              urlize: true
              regex_strip: '[^\w\-]+'
              prefix: http://data.deichman.no/person/
              datatype: uri
            relation: 
              class: FOAF.Person
              subfield:
                a:
                  predicate: RADATANA.catalogueName
                  object:
                    datatype: literal
                j:
                  predicate: XFOAF.nationality
                  object:
                    datatype: uri
                    prefix: 'http://data.deichman.no/nationality/'
                    regex_strip: '[\W]+'


## TODO 

relation subfield relations should accept different classes


