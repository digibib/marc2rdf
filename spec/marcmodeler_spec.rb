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
      stub_request(:get, /tnr_583095/).
         with(:headers => {'Accept'=>'application/sparql-results+json, application/sparql-results+xml'}).
         to_return(:status => 200, :body => @json, :headers => {'Content-Length' => 7038, 'Content-Type' => 'application/sparql-results+json'})
      @modeler = MARCModeler.new(@library)
      @modeler.get_manifestation("http://data.deichman.no/resource/tnr_583095")
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
        @modeler.convert
        @modeler.marc.should be_a(MARC::Record)
      end
      
      it "MARC record should have an identifier" do
        @modeler.convert
        @modeler.marc['001'].value.should == '583095'
      end
      
      it "MARC record should have inversed creator in 100$a" do
        @modeler.convert
        @modeler.marc['100']['a'].should == 'Bache-Wiig, Anna'
      end

      it "MARC record should have creator ID in 100$3" do
        @modeler.convert
        @modeler.marc['100']['3'].should == '32026400'
      end

      it "MARC record should have title in field 245$a" do
        @modeler.convert
        @modeler.marc['245']['a'].should == 'Det aller fineste'
      end

      it "MARC record should have responsible in field 245$c" do
        @modeler.convert
        @modeler.marc['245']['c'].should == 'Anna Bache-Wiig'
      end

    end
        
  end
  

end

