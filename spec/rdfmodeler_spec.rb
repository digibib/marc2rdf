require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDFModeler do
  before(:all) do
    @uri       = "http://example.com/"
    @reader    = MARC::ForgivingReader.new('./spec/test.xml')
    @oairecord = @reader.each { | record | record }
    @oai       = OAI::ListRecordsResponse.new(StringIO.new(@oairecord.to_s))
    #@marcxml   = MARC::XMLReader.new(StringIO.new(@record.metadata.to_s))
  end
  
  context "when converting an OAI record" do
   
    it "should support creating a RDF record from an OAI response" do
      @oai.each { |response| RDFModeler.new(response) }
    end
    
    it "should support creating a RDF::Statement from an OAI response" do
      @oai.each do |response| 
        rdf = RDFModeler.new(response)
        rdf.set_type(RDF::BIBO.Book)
        $statements.should be_a_kind_of(RDF::Statement)
      end
    end
  end
end
