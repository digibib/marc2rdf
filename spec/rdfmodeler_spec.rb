require File.join(File.dirname(__FILE__), 'spec_helper')
describe RDFModeler do

  context "when converting MARC binary file to RDF" do
    before(:each) do
      @reader     = MARC::ForgivingReader.new("./spec/example.binary.normarc.mrc")
    end
    
    it "should support creating a RDF record from an binary MARC record" do
      rdfrecord = RDFModeler.new(@reader.first)
    end
    
    it "should support converting a MARC record to RDF" do
      record = @reader.first
      rdfrecord = RDFModeler.new(record)
      rdfrecord.set_type("BIBO.Document")
      rdfrecord.marc2rdf_convert(record)
    end
        
  end
  
  context "when doing OAI harvesting" do

    before(:each) do
      @oai          = "http://example.com/oai"
      @path         = "/oai"
      @oaixml       = IO.read('./spec/example.bibliofilmarc.xml').force_encoding('ASCII-8BIT')
      @oaitest        = Faraday.new(:url => "http://example.com") do |builder|
        builder.adapter :test do |stub|
          stub.get(@path) {[200, {}, @oaixml]}
        end
      end
      @oaiclient    = OAI::Client.new(@oai, :http => @oaitest)
      @oairesponse  = @oaiclient.list_records :metadata_prefix => 'bibliofilmarc', :from=> "2012-02-09", :until=> "2012-02-09"
      @oairecord    = OAI::Record.new(@oairesponse.doc)
      @marcxml      = MARC::XMLReader.new(StringIO.new(@oairecord.metadata.to_s))
    end
    
    it "should support fetch book ID from an OAI response header" do
       @oairecord.header.identifier.split(':').last.should == "103215"
    end
       
    it "should support creating a RDF record from an OAI response" do
      RDFModeler.new(@marcxml.first)
    end
    
    it "should support creating a RDF::Statement from an OAI response" do
      rdf = RDFModeler.new(@marcxml.first)
      rdf.set_type("BIBO.Document")
      $statements.first.should be_a_kind_of(RDF::Statement)
    end

    it "should support creating a converted RDF record from a OAI record" do
      record = @marcxml.first
      rdfrecord = RDFModeler.new(record)
      rdfrecord.set_type("BIBO.Document")
      rdfrecord.marc2rdf_convert(record)
    end
    
  end
end
