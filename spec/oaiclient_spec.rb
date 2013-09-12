require File.join(File.dirname(__FILE__), 'spec_helper')
describe OAIClient do
  context "when doing OAI harvesting" do

    before(:each) do
      @url         = "http://example.com/oai"
      @path        = "/oai"
      @xml         = IO.read('./spec/example.oairesponse.xml').force_encoding('ASCII-8BIT')
      @oaitest     = Faraday.new(:url => "http://example.com") do |builder|
        builder.adapter :test do |stub|
          stub.get(@path) {[200, {}, @xml]}
        end
      end
      @oaiclient   = OAIClient.new(@url, :http => @oaitest, :format => 'bibliofilmarc')
      @oaiclient.query :from => "1970-01-01", :set => ""
      @marcxml     = MARC::XMLReader.new(StringIO.new(@oaiclient.response.first.metadata.to_s))
    end
    
    it "should support timeout option sent to Faraday request" do
      #faraday = Faraday.new :request => { :timeout => 80 }
      oai  = OAIClient.new(@url, :format => 'bibliofilmarc', :timeout => 80)
      oai.client.instance_variable_get(:@http_client).instance_variable_get(:@options)[:timeout].should == 80
    end
    
    it "should support checking if OAI response contains records" do
       @oaiclient.response.any? == true
    end
        
    it "should support count records in OAI response" do
       @oaiclient.response.count.should == 12
    end

    it "should support fetch resumption token from an OAI response header" do
       @oaiclient.response.resumption_token.should == "24590-1343733244"
    end

    it "should support fetch book ID from an OAI response header" do
       @oaiclient.response.first.header.identifier.split(':').last.should == "103215"
    end

    it "should support checking if an OAI response header stauts is deleted" do
       @oaiclient.response.first.header.deleted? == false
    end
            
               
    it "should support creating a RDF record from an OAI response" do
      RDFModeler.new(1, @marcxml.first)
    end
    
    it "should support creating a RDF::Statement from an OAI response" do
      r = RDFModeler.new(1, @marcxml.first)
      r.set_type("BIBO.Document")
      r.statements.first.should be_a_kind_of(RDF::Statement)
    end

    it "should support converting a MARCXML record to NTriples" do
      record = @marcxml.first
      rdf = RDF::Writer.for(:ntriples).buffer do |writer|
        RDFModeler.class_variable_set(:@@writer, writer)
        default_graph = 'http://example.com'
        default_prefix = 'http://example.com/'
        l = {'id'=>1, 'name'=>'test', 'mapping'=>'dummy', 'oai'=>{'preserve_on_update'=>['FOAF.depiction']}, 
          'config'=>{'resource'=>{'default_graph'=> default_graph, 'base' => default_graph, 'prefix' => '/id_', 'identifier_tag' => '001'}}}
        library = l.to_struct("Library")
        r = RDFModeler.new(library, record)
        r.set_type("BIBO.Document")        
        r.convert
        nt = RDFModeler.write_ntriples(r.statements)
        nt.should be_a String
        nt.should match(/<http:\/\/example\.com\/id_103215>/)
      end
    end
    
  end
end
