require File.join(File.dirname(__FILE__), 'spec_helper')
describe BatchHarvest do
  context "when doing batch harvesting" do

    before(:each) do
      @isbn = "9788203193538"
      @harvester = Harvest.new('dummyid')
      @harvester.protocol = "http"
      @harvester.url = { "prefix" => 'http://example.com/isbn/', "suffix" => '' }
      @harvester.limits = { "max_limit" => 10, "batch_limit" => 10, "retry_limit" => 3, "delay" => 5 }
      @harvester.namespaces = { "xmlns" => "http://worldcat.org/xid/isbn/" }
      @harvester.predicates = { "BIBO.isbn" => {
                      "datatype" => "literal",
                      "xpath" => "//xmlns:isbn"
                      } }
      @batch = RDF::Query::Solutions.new
      @batch << RDF::Query::Solution.new(
                  :work => RDF::URI("http://dummywork"), 
                  :edition => RDF::URI("http://dummyedition"),
                  :object  => @isbn)
      @xml         = IO.read('./spec/example.harvestresponse.xml')
      stub_request(:get, "http://example.com/isbn/#{@isbn}").to_return(:body => @xml, :status => 200)
      
    end
    
    it "should connect a BatchHarvest to a Harvester" do
      h = BatchHarvest.new @harvester
      h.should be_a(BatchHarvest)
      h.harvester.id.should == 'dummyid'
    end
    
    it "should accept an RDF::Query::Solutions as batch input" do
      h = BatchHarvest.new @harvester, @batch
      h.should be_a(BatchHarvest)
      h.harvester.id.should == 'dummyid'
      h.solutions.first.object.should == "9788203193538"
      h.harvester.limits["batch_limit"].should == 10
    end

    it "should run harvester and parse rdf statements" do
      h = BatchHarvest.new @harvester, @batch
      h.harvester.id.should == 'dummyid'
      h.start_harvest
      h.statements.count.should >= 1
    end
        
  end
end
