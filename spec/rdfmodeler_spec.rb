require File.join(File.dirname(__FILE__), 'spec_helper')
describe RDFModeler do
  before(:all) do
    @oai          = "http://example.com/oai"
    @path         = "/oai"
    #@file         = IO.read('./spec/example.bibliofilmarc.xml').force_encoding('ASCII-8BIT')
    @file         = IO.read('./spec/test.xml')
    #@file         = File.open('./spec/test.xml', 'rb') {|f| f.read }
   # @stubs        = Faraday.new("http://example.com") do |builder|
   #   builder.adapter :test, stubs do |stub|
   #     stub.get(@path) {[200, {}, @file]}
   #   end
   # end
    @stubs  = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get(@path) { [200, {}, @file] }
    end
    @oaiclient    = OAI::Client.new(@oai, :http => @stubs)
    @oairesponse  = @oaiclient.list_records :metadata_prefix => 'bibliofilmarc', :from=> "2012-02-09", :until=> "2012-02-09"
    @oairecord    = OAI::Record.new(@oairesponse.doc)
    @marcxml      = MARC::XMLReader.new(StringIO.new(@oairecord.metadata.to_s))
  end
  
  context "when doing OAI harvesting", :oai do
   
    it "should support creating a RDF record from an OAI response" do
      RDFModeler.new(@marcxml)
    end
    
    it "should support creating a RDF::Statement from an OAI response" do
      rdf = RDFModeler.new(@marcxml)
      rdf.set_type(RDF::BIBO.Book)
      $statements.should be_a_kind_of(RDF::Statement)
    end
    
    it "should support fetch book ID from an OAI response header" do
       @oairecord.header.identifier.split(':').last.should == "14890"
    end
    
  end
end
