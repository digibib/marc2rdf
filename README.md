# MARC bibliographic record to RDF converter

    MARC2RDF - a ruby toolkit to convert bibliographic MARC to RDF by YAML mapping
    Copyright (C) 2014 Benjamin Rokseth
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

### Architecture
![API architecture](https://github.com/digibib/marc2rdf/raw/master/doc/schematics.png)

## HOW IT WORKS

The webapp is built upon the notion of syncing one or more bibliographic repositories, `Libraries`, to an updated 
RDF triplestore. Each `Library` connects to an OAI-PMH repository (bibliographic metadata) service and harvests 
metadata once or regularly, maps it to RDF in the `mapping` module, and converts it to RDF and inserts it to
a triplestore via the `conversion` module.

In addition there is a `rules` module, in which SPARQL rules can be made for updating/modifying RDFstore on the fly, 
either once or regularly. And a `harvester` module, which can be used to harvest metadata from other web APIs, 
based on OAI harvested content or existing RDF.

### HOW TO RUN

A typical setup would be:

* Setup a RDF store and edit settings.json to reflect admin rights
* start app: `foreman start` (will default to 'development' mode, reading 'Procfile')
* Create a `Library` and fill in settings such as OAI endpoint, tag and resource and default graph
* Validate OAI, choose specific set if wanted
* Create a `Mapping` either from scratch or clone existing
* Test mapping against library in the `Conversion` module, by inputting a known id from the OAI repo
* Modify `Mapping` and test until expected results
* Alternatively, generate `Rules` to massage data after harvest and activate on `Library`
* Alternatively, generate `Harvest` to harvest further metadata from other sources and activate on `Library`
* Set OAI harvest schedule to automate process daily 


## FEATURES

The marc2rdf toolkit consists of a web frontend and three parts:

* app.rb       - Main Sinatra webapp
* api.rb       - Grape API for RESTful interaction between app and browser 
* scheduler.rb - Rufus Scheduler to manage job/cron queues

Scheduler takes these job types:

* Single oai harvest (job)
* Recurring oai harvest (cronjob)
* Single SPARQL job (isql job) 
* Recurring SPARQL job (isql cronjob)

Full harvest is generally recommended done in two steps and not enabled in web frontend.
To do this you need to fire two RESTful requests

* Full OAI harvest. This will harvest entire repo from beginning of time to XML dumps
(all saved OAI responses will end up in './db/converted/full')

    http PUT http://localhost:3000/api/oai/harvest_full \
      SECRET_SESSION_KEY:'secretsessionkey' id=<id of library>

* Full OAI conversion. This will use full XML dumps harvested in above step.
It will also run any rules and harvester rules activated on library

    http PUT http://localhost:3000/api/oai/convert_full \
      SECRET_SESSION_KEY:'secretsessionkey' id=<id of library>
      sparql_update=bool write_records=bool

### REQUIREMENTS

* ruby >= 1.9.3, recommended installed via Ruby Version Manager (rvm)
* ruby bundler >= 1.3.5, install by `gem install bundler`

Requirements for tools/marcfix.pl

 * Perl
 * MARC::Record perl module from [CPAN](http://search.cpan.org/~gmcharlt/MARC-Record-2.0.3/lib/MARC/Record.pm)

### INSTALL

Here is a short walk-trough on how to install the needed tools and libraries.

1. Clone this repository form github  
	* ```git://github.com/digibib/marc2rdf.git```  
	This creates a subdirectory called marc2rdf

1. Either install ruby via rvm (Ruby Version Manager, instructions at https://rvm.io/rvm/install) or install ruby-dev  
	*  Ubuntu install (for ruby and rdf-xml support)  
	```sudo apt-get install ruby-dev libxml2-dev libxslt1-dev libyaml-ruby libzlib-ruby rubygems```  
	* Debian note  
	Debian adds a version postfix to the ruby executables. Thus all references to `ruby` becomes 
	`ruby1.8` and references to `gem` becomes `gem1.8`.

1. Install/Update RubyGems bundler  
	```sudo gem install bundler```  
	If you can not or do not want to install RubyGems into system folder locations, please have a look at 
	http://docs.rubygems.org/read/chapter/3/

1. Install needed gems given in Gemfile:  
	```
	cd marc2rdf
	bundle install
	```

### Configuration

  Most configurations are made within app, but for startup repository connection and login settings, 
  copy configuration file  :
	```
	cp ./config/example.settings.json ./config/settings.json
	```  
	* Make changes to the new files as needed to fit your system
  * Set login username and password 
  * Port and host settings are in Procfile (development) and Procfile.production (production)

  setup of libraries, mappings, rules, harvests & vocabularies are made within app, 
  but for convenience we have added our current setup in the following gist:
  https://gist.github.com/anonymous/6206748

### Production

  When ready for production mode, the included Procfile.production can be used as an example:
  
  `foreman start -f Procfile.production`
  
  Webapp should then run blazingly fast, as pages are no longer reloaded each load. (Development
  mode reloads app on each page load).
  
  Foreman can also be used to create upstart jobs easily (managed by linux system and respawned if down):
  
  `rvmsudo foreman export upstart /etc/init -p Procfile.production -a marc2rdf`
  
  Read more about foreman at: http://ddollar.github.io/foreman/
  
### Binary MARC
  
Usage of binary MARC is generally not recommended, and only supported in single batch conversion. But you'll need to:

1. Install Perl and MARC::Record  
	On Debian and Ubuntu these are installed with apt:  
	```
	apt-get install perl libmarc-record-perl
	```  
	MARC::Record can also be installed with 
	[CPAN](http://search.cpan.org/~gmcharlt/MARC-Record-2.0.3/lib/MARC/Record.pm)  

### RDF STORE

 * Recommended triplestore is OpenLink Virtuoso, minimum version v6.1.4, recommended v7.0.0
 * Rules Engine is based on isql Sparql scripts, so rules will only work on virtuoso for now 

#### Ubuntu

```
sudo apt-get install virtuoso-opensource
```

#### Debian

Debian squeeze does not have a recent version of Virtuoso. Please compile from source as described 
over at [their site](http://virtuoso.openlinksw.com/dataspace/dav/wiki/Main/VOSDebianNotes). 

Debian wheezy comes with Virtuoso version 6.1.4, as does Ubuntu 12.04 Precise.

#### Mapping extras

* tag numbers can be regex (e.g. "^5(?!71)" for 500-599 minus 571)
* predicates are given in format PREFIX.suffix and non-standard prefixes must exist in ./lib/vocabularies.rb
* objects prefixes must be exploded 
* predicates can be conditionally mapped from subfields or indicators
* objects can have language tags given as symbols (:se, :en_UK etc)
* objects can be mapped key => values
* relations can have subfields
* string replace non-ascii characters to create uris
* oai harvester uses same mapping
* erroneous 000 marc field in normarc can be removed with perl script ./tools/marcfix.pl

