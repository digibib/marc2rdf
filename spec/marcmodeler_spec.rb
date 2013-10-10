require File.join(File.dirname(__FILE__), 'spec_helper')
describe MARCModeler do

  context "when converting RDF to MARCXML" do
    before(:each) do
      @endpoint = SETTINGS["repository"]["sparul_endpoint"]
      default_graph = 'http://data.deichman.no/books'
      base = 'http://data.deichman.no/resource/'
      l = {'id'=>1, 'name'=>'test', 
          'config'=>{'resource'=>{'default_graph'=> default_graph, 'base' => base, 'prefix' => 'tnr_', 'identifier_tag' => '001'}}}
      @library = l.to_struct("Library")
      @json = IO.read('./spec/example.sparqlresponse_manifestation.json')
      @emptyjson = IO.read('./spec/example.sparqlresponse_empty.json')
      # make sure to stub request before tests!
      #stub_request(:get, "http://datatest.deichman.no/sparql-auth/?format=application/sparql-results%2Bjson&query=SELECT%20*%20FROM%20%3Chttp://data.deichman.no/books%3E%20WHERE%20%7B%20%3Chttp://data.deichman.no/resource/tnr_583095%3E%20%3Chttp://purl.org/dc/terms/identifier%3E%20?id%20.%20%3Chttp://data.deichman.no/resource/tnr_583095%3E%20%3Chttp://purl.org/dc/terms/title%3E%20?title%20.%20%3Chttp://data.deichman.no/resource/tnr_583095%3E%20%3Chttp://rdvocab.info/Elements/statementOfResponsibility%3E%20?responsible%20.%20%3Chttp://data.deichman.no/resource/tnr_583095%3E%20%3Chttp://purl.org/dc/terms/creator%3E%20?creatorURI%20.%20?creatorURI%20%3Chttp://def.bibsys.no/xmlns/radatana/1.0%23catalogueName%3E%20?creatorName%20.%20?creatorURI%20%3Chttp://purl.org/dc/terms/identifier%3E%20?creatorID%20.%20OPTIONAL%20%7B%20%3Chttp://data.deichman.no/resource/tnr_583095%3E%20%3Chttp://purl.org/spar/fabio/hasSubtitle%3E%20?subtitle%20.%20%7D%20OPTIONAL%20%7B%20%3Chttp://data.deichman.no/resource/tnr_583095%3E%20%3Chttp://purl.org/ontology/bibo/isbn%3E%20?isbn%20.%20%7D%20OPTIONAL%20%7B%20%3Chttp://data.deichman.no/resource/tnr_583095%3E%20%3Chttp://purl.org/ontology/bibo/issn%3E%20?issn%20.%20%7D%20%7D").
      stub_request(:get, /tnr_583095/).
         with(:headers => {'Accept'=>'application/sparql-results+json, application/sparql-results+xml'}).
         to_return(:status => 200, :body => @json, :headers => {'Content-Length' => 7038, 'Content-Type' => 'application/sparql-results+json'})
      @modeler = MARCModeler.new(@library)
      @modeler.get_manifestation("http://data.deichman.no/resource/tnr_583095")
      @modeler.convert
    end
    
    describe "creating manifestation" do

      it "should accept an uri" do
        @modeler.uri.should be_a(RDF::URI)
      end

      it "should return nil when using an uri of non-existing resource" do
        stub_request(:get, /tnr_dummy/).
          with(:headers => {'Accept'=>'application/sparql-results+json, application/sparql-results+xml'}).
          to_return(:status => 200, :body => @emptyjson, :headers => {'Content-Length' => 7038, 'Content-Type' => 'application/sparql-results+json'})
        @modeler.get_manifestation("http://data.deichman.no/resource/tnr_dummy")
        @modeler.manifestation.should be_nil
      end

      it "should read create RDF::Query::Solutions from uri" do
        @modeler.manifestation.should be_a(RDF::Query::Solutions)
      end

    end

    describe "converting to MARC" do

      it "should support creating a MARC record from an RDF Manifestation" do
        @modeler.marc.should be_a(MARC::Record)
      end
      
      it "MARC record should have an identifier" do
        @modeler.marc['001'].value.should == '583095'
      end
      
      # it "MARC record should have agelimit in field 019$s" do
      #   @modeler.marc['019'].should be_nil
      # end

      it "MARC record should have isbn in field 020$a" do
        @modeler.marc['020']['a'].should == '8210047981'
      end

      it "MARC record should have inversed creator in 100$a" do
        @modeler.marc['100']['a'].should == 'Bache-Wiig, Anna'
      end

      it "MARC record should have creator ID in 100$3" do
        @modeler.marc['100']['3'].should == '32026400'
      end

      it "MARC record should have title in field 245$a" do
        @modeler.marc['245']['a'].should == 'Det aller fineste'
      end

      it "MARC record should have responsible in field 245$c" do
        @modeler.marc['245']['c'].should == 'Anna Bache-Wiig'
      end

    end

    describe "outputting XML" do 
      it "should return MARCXML from record" do
        @modeler.write_xml
        @modeler.marcxml.should be_a(REXML::Element || LIBXML::Node)
      end
    end
  end
  

end

