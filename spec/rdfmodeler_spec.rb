require File.join(File.dirname(__FILE__), 'spec_helper')
describe RDFModeler do

  context "when converting MARC binary file to RDF" do
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
  
  context "when doing OAI harvesting" do



    before(:each) do
      @oai          = "http://example.com/oai"
      @path         = "/oai"
      @oaixml       = IO.read('./spec/example.oairesponse.xml').force_encoding('ASCII-8BIT')
      @oaitest        = Faraday.new(:url => "http://example.com") do |builder|
        builder.adapter :test do |stub|
          stub.get(@path) {[200, {}, @oaixml]}
        end
      end
      @oaiclient    = OAI::Client.new(@oai, :http => @oaitest)
      @oairesponse  = @oaiclient.list_records :metadata_prefix => 'bibliofilmarc', :from=> "1970-01-01"
      @oairecords   = @oairesponse.entries
      @marcxml      = MARC::XMLReader.new(StringIO.new(@oairecords.first.metadata.to_s))
    end
    
    it "should support timeout option sent to Faraday request" do
      timeout = 80
      faraday = Faraday.new :request => { :timeout => timeout }
      client  = OAI::Client.new(@oai, :http => faraday)
      client.instance_variable_get(:@http_client).instance_variable_get(:@options)[:timeout].should == 80
    end
    
    it "should support checking if OAI response contains records" do
       @oairesponse.any? == true
    end
        
    it "should support count records in OAI response" do
       @oairesponse.count.should == 12
    end

    it "should support fetch resumption token from an OAI response header" do
       @oairesponse.resumption_token.should == "24590-1343733244"
    end

    it "should support fetch book ID from an OAI response header" do
       @oairesponse.first.header.identifier.split(':').last.should == "103215"
    end

    it "should support checking if an OAI response header stauts is deleted" do
       @oairesponse.first.header.deleted? == false
    end
            
               
    it "should support creating a RDF record from an OAI response" do
      RDFModeler.new(1, @marcxml.first)
    end
    
    it "should support creating a RDF::Statement from an OAI response" do
      r = RDFModeler.new(1, @marcxml.first)
      r.set_type("BIBO.Document")
      r.statements.first.should be_a_kind_of(RDF::Statement)
    end

    it "should support converting a MARCXML record to a RDF statements array" do
      record = @marcxml.first
      rdf = RDF::Writer.for(:ntriples).buffer do |writer|
        RDFModeler.class_variable_set(:@@writer, writer)
        r = RDFModeler.new(1, record)
        r.set_type("BIBO.Document")        
        r.convert
        r.write_record
        r.statements[1].to_s.should == "<http://data.deichman.no/resource/tnr_103215> <http://purl.org/dc/terms/identifier> 103215 ."
      end
    end
    
  end
end
