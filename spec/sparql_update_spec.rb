require File.join(File.dirname(__FILE__), 'spec_helper')

describe SparqlUpdate do

  before(:all) do
    @endpoint   = "http://localhost:8890"
    @uri = "http://example.com/"
    @query = RDF::Virtuoso::Query
    @book_id = "12345678"
    $statements = [
      RDF::URI(@uri + @book_id),
      RDF.type,
      RDF::URI(RDF::BIBO.Document)
      ]
  end
  
  context "when updating a book" do
    it "should support connecting to a Virtuoso SPARQL endpoint" do
      RDF::Virtuoso::Client.new(@endpoint)
    end
    
    it "should support connecting to a Virtuoso SPARUL endpoint with BASIC AUTH" do
      RDF::Virtuoso::Client.new(@endpoint, :username => 'admin', :password => 'secret', :auth_method => 'basic')
    end
    
    it "should support connecting to a Virtuoso SPARUL endpoint with DIGEST AUTH" do
      RDF::Virtuoso::Client.new(@endpoint, :username => 'admin', :password => 'secret', :auth_method => 'digest')
    end
    
    it "should support updating a book" do
      SparqlUpdate.sparql_update(@book_id)
    end
    
    it "should support updating a book without removing harvested info" do
      preserve = ["FOAF.depiction", "REV.hasReview"]
      SparqlUpdate.sparql_update(@book_id, :preserve => preserve)
    end
    
    it "should support deleting a book entirely" do
      SparqlUpdate.sparql_purge(@book_id)
    end
  end
end
