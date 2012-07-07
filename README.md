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

## HOWTO

### INSTALL

either install ruby via rvm (Ruby Version Manager) or install ruby-dev

#### UBUNTU INSTALL

(for rdf-xml support)
    sudo apt-get install libxml2-dev libxslt1-dev
    gem install bundler

install needed gems given in Gemfile:

    bundle install

copy needed configuration files

    cp ./config/config.yml-dist ./config/config.yml
    cp ./config/harvesting.yml-dist ./config/harvesting.yml
  
and make changes as needed to fit your system

### RDF STORE

* Recommended triplestore is OpenLink Virtuoso, minimum version 6.1.3
* any other triplestore should work fine, though, as long as it supports SPARQL 1.1 UPDATE LANGUAGE

#### UBUNTU

    sudo apt-get install virtuoso-opensource

### PREPARATION

Command line options are listed by running either of the three scripts.

A typical conversion consists of:

* converting an entire MARC binary record set with marc2rdf.rb.
* splitting up and importing result RDF to a triplestore
* setting up cron job to use OAI-PMH repository with oai_harvester.rb
* adding sources to harvest and reap the internet with harvester.rb

Before conversion, care must be taken to setup config files under ./config

three config files are needed:

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
* erronemous 000 marc field in normarc can be removed with perl script ./tools/marcfix.pl

## FILES INCLUDED

* marc2rdf.rb                            -- main ruby script to convert NORMARC file to RDF
* oai.rb								 -- oai harvester skript to harvest and update rdf store
* lib/
    * string_replace.rb 
    * rdfmodeler.rb
    * sparql_update.rb  
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

## REQUIREMENTS

* ruby >= 1.8.7
* ruby-marc (thanks to Ross Singer et.al.)
* rdf.rb (thanks to Arto Bendiken et.al. for the brilliant RDF library for ruby)
* rdf-rdfxml.rb (requires development libraries libxml2 and libxslt1)
* rest-client
* oai
* sparql/client from git, branch virtuoso_update
