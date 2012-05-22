# MARC bibliographic record to RDF converter

    MARC2RDF - a ruby program to convert binary MARC to RDF by YAML mapping
    Copyright (C) 2012 Benjamin Rokseth
    Purpose: Convert binary marc to semantic markup using yaml mapping file
             Add OAI harvester and rdf store to host live rdf repository

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

## FILES

* marc2rdf.rb                            -- main ruby script to convert NORMARC file to RDF
* oai.rb								 -- oai harvester skript to harvest and update rdf store
* lib/
    * string_replace.rb 
    * rdfmodeler.rb
    * sparql_update.rb  
* config/
    * config-dist.yml                    -- config file
    * mapping-normarc2rdf.yml            -- example mapping file: NORMARC tags to rdf mapping
    * mapping-normarc2rdf_bildebaser.yml -- example mapping file: image base in NORMARC
* hamsun_fikset.mrc                         -- test NORMARC file
* output.rdf                                -- test output RDF with -r 50 (50 records)

## MAPPING

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

## FEATURES

For full list of functions see example YAML file 'config/mapping-normarc2rdf.yml' based on NORMARC variant of USMARC

* tag numbers can be regex (e.g. "^5(?!71)" for 500-599 minus 571)
* all uris are exploded in yaml file, and objects need full prefix 
* predicates can be conditionally mapped from subfields or indicators
* objects can have language tags given as symbols (:se, :en_UK etc)
* objects can be mapped key => values
* relations can have subfields
* string replace non-ascii characters to create uris
* oai harvester and rdf store updates with RestClient
* erronemous 000 marc field in normarc can be removed with perl script tools/marcfix.pl

## TODO 

relation subfield relations should accept different classes

## REQUIREMENTS

* ruby >= 1.8.7
* ruby-marc (thanks to Ross Singer et.al.)
* rdf.rb (thanks to Arto Bendiken et.al. for the brilliant RDF library for ruby)
* rdf-rdfxml.rb (requires development libraries libxml2 and libxslt1)
* rest-client
* oai

## LINUX USERS

either install via rvm (Ruby Version Manager)
or install ruby-dev

## UBUNTU INSTALL

(for rdf-xml support)
* sudo apt-get install libxml2-dev libxslt1-dev
* gem install bundler
* bundle install

## USAGE 

    marc2rdf.rb -i input_file -o output_file [-r recordlimit]
      -i input_file must be marc binary
      -o output_file extension can be either .rdf (slooow) or .nt (very fast)
      -r [number] stops processing after given number of records
