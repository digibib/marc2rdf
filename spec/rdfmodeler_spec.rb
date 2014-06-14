require File.join(File.dirname(__FILE__), 'spec_helper')
describe RDFModeler do

  context "when converting MARC (binary) file to RDF" do
    before(:each) do
      @reader     = MARC::ForgivingReader.new("./spec/example.binary.normarc.mrc")
    end
    
    it "should support creating a RDF record from an binary MARC record" do
      r = RDFModeler.new(1, @reader.first)
      r.library_id.should == 1
    end
    
    it "should support converting a MARC record to RDF" do
      record = @reader.first
      r = RDFModeler.new(1, record)
      r.set_type("BIBO.Document")
      r.convert
      r.statements.count.should >= 1
    end
        
  end
  
  context "generating RDF objects" do
    before(:each) do
      @reader     = MARC::ForgivingReader.new("./spec/example.binary.normarc.mrc")
      @rdfmodeler = RDFModeler.new(1, @reader.first)
      @str = "abcdef"
    end


    it "should support substring offset and substring length" do
      obj = @rdfmodeler.generate_objects(@str, {:substr_offset => 2, :substr_length => 4})
      obj.first.should == "cdef"
    end

    it "should return empty object when :substr_length and :substr_offset exceeds length of string" do
      obj = @rdfmodeler.generate_objects(@str, {:substr_offset => 11, :substr_length => 1})
      obj.should be_empty
    end

    it "generated URIs should be of type RDF::URI" do
      uri = @rdfmodeler.generate_uri(@str, "http://example.com/")
      uri.should be_a RDF::URI
    end

    it "trying to generate URI object with invalid characters should result in RDF::Literal" do
      uri = @rdfmodeler.generate_uri(@str, "http:||example.com")
      uri.should be_a RDF::Literal
    end

    it "trying to generate URI object with missing prefix should result in RDF::Literal" do
      uri = @rdfmodeler.generate_uri(@str, "www.example.com")
      puts uri.inspect
      uri.should be_a RDF::Literal
    end

    it "should regex_split and then regex_substitute" do
      obj = @rdfmodeler.generate_objects(@str, {:regex_split => "(\\w{2})", :regex_substitute => {
              "orig" => "ab|cd|ef", 
              "subs" => {"ab" => "AA", "cd" => "BB", "ef" => "CC"}, 
              "default" => "ZERO"
            } 
          })
      obj.should == ["AA","BB","CC"]
    end
    it "should combine subfields with chosen combinestring" do
      obj = @rdfmodeler.generate_objects(@str, {
          :marcfield => MARC::DataField.new('245', ' ',  ' ', ['a', 'A Title'], ['b', 'A Subtitle']),
          :combine => ["a", "b"], 
          :combinestring => " : "
        })
      obj.first.should == "A Title : A Subtitle"
    end
    it "should urlize a string, defaulting to convert spaces and downcase" do
      str = "A Simple String"
      obj = @rdfmodeler.generate_objects(str, { :urlize => true })
      obj.first.should == "a_simple_string"
    end
    it "should be able NOT to downcase and convert_spaces in urlize" do
      str = "A Simple String"
      obj = @rdfmodeler.generate_objects(str, { :urlize => true, :no_downcase => true, :no_convert_spaces => true })
      obj.first.should == "ASimpleString"
    end
    it "should urlize special characters against mapping in String module" do
      str = "\u00C6gir"
      obj = @rdfmodeler.generate_objects(str, { :urlize => true} )
      obj.first.should == "aegir"
    end
    it "should urlize with custom regexp" do
      str = "abcdef"
      obj = @rdfmodeler.generate_objects(str, { :urlize => true, :regexp => /[^a-e]/} )
      obj.first.should == "abcde"
    end    
  end

  context "advanced RDF modelling and conversion" do
    before(:each) do
      base = 'http://data.deichman.no/resource/'
      l = {'id'=>1, 'name'=>'test', 
          'config'=>{'resource'=>{'base' => base, 'prefix' => 'tnr_', 'identifier_tag' => '001'}}}
      @library = l.to_struct("Library")
      @marcxml = MARC::XMLReader.new("./spec/example.normarc.xml")
      template = File.join(File.dirname(__FILE__), '..', 'config', 'templates', 'mappings.json')
      json = JSON.parse(IO.read(template))
      @map = json.first.to_struct("Mapping")
    end

    it "allows alternative mapping as param" do
      r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
      r.map.name.should == "Example Mapping"
    end

    context "generating literals" do
      it "allows a modified mapping as param" do
        @map.mapping["tags"]["020"] = {
          "subfield" => {
            "a" => {
              "predicate" => "BIBO.isbn", 
              "object" => {
                "datatype" => "literal"
              }
            }
          }
        }
        r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://purl.org/ontology/bibo/isbn")
      end

      it "creates literals with datatype integers" do
        @map.mapping["tags"]["300"] = {
          "subfield" => {
            "a" => {
              "predicate" => "BIBO.isbn", 
              "object" => {
                "datatype" => "integer",
                "regex_strip" => "[\\D]+",
              }
            }
          }
        }
        r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
        r.convert
        r.statements.to_s.should include("\"202\"^^<http://www.w3.org/2001/XMLSchema#integer>")
      end
      it "creates literals with datatype float" do
        @map.mapping["tags"]["300"] = {
          "subfield" => {
            "a" => {
              "predicate" => "BIBO.isbn", 
              "object" => {
                "datatype" => "float",
                "regex_strip" => "[\\D]+",
              }
            }
          }
        }
        r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
        r.convert
        r.statements.to_s.should include("\"202\"^^<http://www.w3.org/2001/XMLSchema#float>")
      end
    end

    context "generating URIs" do
      it "creates an format URI from ControlField 008" do
        @map.mapping["tags"]["008"] = {
          "audience" => {
              "predicate" => "DC.audience",
              "object" => {
                  "datatype" => "uri",
                  "prefix" => "http://data.deichman.no/audience/",
                  "substr_length" => 1,
                  "regex_substitute" => {
                      "default" => "adult",
                      "subs" => {
                          "a" => "adult",
                          "j" => "juvenile"
                      },
                      "orig" => "a|j"
                  },
                  "substr_offset" => 22
              }
            }
          }
        r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://data.deichman.no/audience/adult")
      end
      it "creates a Class from language relation from ControlField 008" do
        @map.mapping["tags"]["008"] = {
          "language" => {
              "predicate" => "DC.language",
              "object" => {
                  "datatype" => "uri",
                  "prefix" => "http://lexvo.org/id/iso639-3/",
                  "substr_length" => 3,
                  "substr_offset" => 35
                  },
              "relation" => {
                "class" => "LVONT.Language"
              }
            }
          }
        r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://lexvo.org/ontology#Language")
      end

      it "creates an format URI from DataField" do
        @map.mapping["tags"]["019"] = {
          "subfield" => {
            "b" => {
              "predicate" => "DC.format", 
              "object" => {
                "datatype" => "uri",
                  "prefix" => "http://data.deichman.no/format/",
                  "regex_substitute" => {
                    "default" => "Document",
                    "subs" => { "l" => "Book" },
                    "orig" => "l"
                  }
                }
              }
            }
          }
        r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://data.deichman.no/format/Book")
      end
      it "creates an format URI from conditions on a subfield" do
        @map.mapping["tags"]["700"] = {
          "subfield" => {
            "3" => {
              "object" => {
                "datatype" => "uri",
                "prefix" => "http://example.com/person/x"
              },
              "conditions" => {
                "subfield" => {
                  "e" => {
                    "default" => "DC.contributor", 
                    "subs" => { "overs" => "BIBO.translator" },
                    "orig" => "overs"  
                    }
                  }
                }
              }
            }
          }
        r = RDFModeler.new(@library, @marcxml.entries[1], :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://purl.org/ontology/bibo/translator")
      end
      it "on failed conditions default should be used" do
        @map.mapping["tags"]["700"] = {
          "subfield" => {
            "3" => {
              "object" => {
                "datatype" => "uri",
                "prefix" => "http://example.com/person/x"
              },
              "conditions" => {
                "subfield" => {
                  "e" => {
                    "default" => "DC.contributor", 
                    "subs" => { "overs" => "BIBO.translator" },
                    "orig" => "nonexistingcondition"  
                    }
                  }
                }
              }
            }
          }
        r = RDFModeler.new(@library, @marcxml.entries[1], :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://purl.org/dc/terms/contributor")
      end
      it "conditions against an empty or nonexisting subfield, should use default" do
        @map.mapping["tags"]["700"] = {
          "subfield" => {
            "3" => {
              "object" => {
                "datatype" => "uri",
                "prefix" => "http://example.com/person/x"
              },
              "conditions" => {
                "subfield" => {
                  "nonexistingsubfield" => {
                    "default" => "DC.contributor", 
                    "subs" => { "ignore" => "ignore" },
                    "orig" => "nonexistingcondition"  
                    }
                  }
                }
              }
            }
          }
        r = RDFModeler.new(@library, @marcxml.entries[1], :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://purl.org/dc/terms/contributor")
      end       
      it "chooses predicate based on conditions from indicator 1" do
        @map.mapping["tags"]["240"] = {
          "subfield" => {
            "a" => {
              "object" => {
                "datatype" => "literal"
              },
              "conditions" => {
                "indicator" => {
                  "default" => "DC.originalTitle", 
                  "indicator1" => {
                    "subs" => {
                      "0" => "DC.originalTitle", 
                      "1" => "DC.uniformTitle"
                    }, 
                    "orig" => "0|1"
                  }
                }
              }
            }
          }
        }
        r = RDFModeler.new(@library, @marcxml.entries[1], :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://purl.org/dc/terms/uniformTitle")
      end
      it "chooses predicate based on conditions from indicator 2" do
        @map.mapping["tags"]["245"] = {
          "subfield" => {
            "a" => {
              "object" => {
                "datatype" => "literal"
              },
              "conditions" => {
                "indicator" => {
                  "default" => "DC.anyTitle", 
                  "indicator2" => {
                    "subs" => {
                      "0" => "DC.someTitle", 
                      "1" => "DC.anotherTitle"
                    }, 
                    "orig" => "0|1"
                  }
                }
              }
            }
          }
        }
        r = RDFModeler.new(@library, @marcxml.entries[1], :mapping => @map)
        r.convert
        r.statements.to_s.should include("http://purl.org/dc/terms/someTitle")
      end
    end    
  end
end