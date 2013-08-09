require File.join(File.dirname(__FILE__), 'spec_helper')
describe BatchHarvest do
  context "when doing batch harvesting" do

    before(:each) do
      @isbn = "9788203193538"
      @harvester = Harvest.new('dummyid')
      @harvester.protocol = "http"
      @harvester.url = { "prefix" => 'http://example.com/isbn/', "suffix" => '' }
      @harvester.limits = { "max_limit" => 10, "batch_limit" => 10, "retry_limit" => 3, "delay" => 5 }
      @harvester.remote = {} 
      @harvester.remote["namespaces"] = {"xmlns" => "http://worldcat.org/xid/isbn/" }
      @harvester.remote["predicates"] = {"BIBO.isbn" => {
                                          "datatype" => "literal",
                                          "xpath" => "//xmlns:isbn"
                                          } }
      @harvester.local = {} 
      @harvester.local["subject"] = "edition"
      @harvester.local["predicate"] = "BIBO.isbn"
      @batch = RDF::Query::Solutions.new
      @batch << RDF::Query::Solution.new(
                  :work => RDF::URI("http://dummywork"), 
                  :edition => RDF::URI("http://dummyedition"),
                  :object  => @isbn)
      @xml         = IO.read('./spec/example.harvestresponse.xml')

      stub_request(:get, "http://example.com/isbn/#{@isbn}").to_return(:body => @xml, :status => 200)
      
    end
    
    it "should connect a BatchHarvest to a Harvester" do
      bh = BatchHarvest.new @harvester
      bh.should be_a(BatchHarvest)
      bh.harvester.id.should == 'dummyid'
    end
    
    it "should accept an RDF::Query::Solutions as batch input" do
      bh = BatchHarvest.new @harvester, @batch
      bh.should be_a(BatchHarvest)
      bh.harvester.id.should == 'dummyid'
      bh.solutions.first.object.should == "9788203193538"
      bh.harvester.limits["batch_limit"].should == 10
    end

    it "should run harvester and parse rdf statements" do
      bh = BatchHarvest.new @harvester, @batch
      bh.harvester.id.should == 'dummyid'
      bh.start_harvest
      bh.statements.count.should >= 1
    end
        
  end
end
