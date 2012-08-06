require File.join(File.dirname(__FILE__), 'spec_helper')

describe SparqlUpdate do

  before(:all) do
    @endpoint   = "http://localhost:8890"
    @uri = "http://example.com/"
    @client = RDF::Virtuoso::Client
  end
  
  context "when connecting to a triplestore" do
    it "should support connecting to a SPARQL endpoint" do
      @client.new(@endpoint)
    end
    
    it "should support connecting to a SPARUL endpoint with BASIC AUTH" do
      @client.new(@endpoint, :username => 'admin', :password => 'secret', :auth_method => 'basic')
    end
    
    it "should support connecting to a SPARUL endpoint with DIGEST AUTH" do
      @client.new(@endpoint, :username => 'admin', :password => 'secret', :auth_method => 'digest')
    end
  end
  
  context "when doing a SPARQL UPDATE" do
    before(:all) do
      @query = RDF::Virtuoso::Query
      
      #$debug = true
      @book_id = "1234567890"
      $statements = [
        RDF::URI(@uri + @book_id),
        RDF.type,
        RDF::URI(RDF::BIBO.Document)
        ]
    end
    
    it "should support updating a book" do
      response = SparqlUpdate.sparql_update(@book_id)
      response.should match(/(done|nothing)/)
      response.should_not match(/NULL/)
    end
    
    it "should support updating a book while preserving harvested info" do
      preserve = ["FOAF.depiction", "REV.hasReview"]
      response = SparqlUpdate.sparql_update(@book_id, :preserve => preserve)
      response.should match(/(done|nothing)/)
      response.should_not match(/NULL/)
    end
    
    it "should support deleting a book entirely" do
      response = SparqlUpdate.sparql_purge(@book_id)
      response.should match(/(done|nothing)/)
      response.should_not match(/NULL/)
    end
  end
end
