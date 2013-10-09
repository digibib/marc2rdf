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
      stub_request(:get, @endpoint + "?format=application/sparql-results%2Bjson&query=SELECT%20*%20FROM%20%3Chttp://data.deichman.no/books%3E%20WHERE%20%7B%20%3Chttp://data.deichman.no/resource/tnr_583095%3E%20?p%20?o%20.%20%7D").
         with(:headers => {'Accept'=>'application/sparql-results+json, application/sparql-results+xml'}).
         to_return(:status => 200, :body => @json, :headers => {'Content-Length' => 7038, 'Content-Type' => 'application/sparql-results+json'})
      @modeler = MARCModeler.new(@library)
    end
    
    describe "" do
      before(:each) do
        @modeler.get_manifestation("http://data.deichman.no/resource/tnr_583095")
      end

      it "should accept an uri" do
        @modeler.uri.should be_a(RDF::URI)
      end

      it "should not fail when using an uri of non-existing resource" do
        stub_request(:get, @endpoint + "?format=application/sparql-results%2Bjson&query=SELECT%20*%20FROM%20%3Chttp://data.deichman.no/books%3E%20WHERE%20%7B%20%3Chttp://data.deichman.no/resource/tnr_dummy%3E%20?p%20?o%20.%20%7D").
          with(:headers => {'Accept'=>'application/sparql-results+json, application/sparql-results+xml'}).
          to_return(:status => 200, :body => @emptyjson, :headers => {'Content-Length' => 7038, 'Content-Type' => 'application/sparql-results+json'})
        @modeler.get_manifestation("http://data.deichman.no/resource/tnr_dummy")
        @modeler.manifestation.should be_empty
      end

      it "should read create RDF::Query::Solutions from uri" do
        @modeler.manifestation.should be_a(RDF::Query::Solutions)
      end

      it "should support creating a MARC record from an RDF Manifestation" do
        @modeler.manifestation.each do |solution|
          #puts solution.inspect
        end
      end
    end
        
  end
  

end

