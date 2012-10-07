require File.join(File.dirname(__FILE__), 'spec_helper')

describe SparqlUpdate do

  before(:all) do
    @sparql_endpoint   = "http://localhost:8890/sparql"
    @sparul_endpoint   = "http://localhost:8890/sparql-auth"
    @uri = "http://example.com/"
    @repo = RDF::Virtuoso::Repository
    #$debug = true
  end
  
  context "when connecting to a triplestore" do
    it "should support connecting to a SPARQL endpoint" do
      repo = @repo.new(@sparql_endpoint)
    end
    
    it "should support connecting to a SPARUL endpoint with BASIC AUTH" do
      @repo.new(@sparql_endpoint, :update_uri => @sparul_endpoint, :username => 'admin', :password => 'secret', :auth_method => 'basic')
    end
    
    it "should support connecting to a SPARUL endpoint with DIGEST AUTH" do
      @repo.new(@sparql_endpoint, :update_uri => @sparul_endpoint, :username => 'admin', :password => 'secret', :auth_method => 'digest')
    end
  end
  
  context "when doing a SPARQL UPDATE from OAI response" do
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
      response = OAIUpdate.sparql_update(@book_id)
      #p response
      response.should match(/(done|nothing)/)
      response.should_not match(/NULL/)
    end
    
    it "should actually insert correct data when updating a book" do
      response = OAIUpdate.sparql_purge(@book_id)
      response = OAIUpdate.sparql_update(@book_id)

      repo = @repo.new(@sparql_endpoint)
      query = @query.select(:type)
      query.where([RDF::URI(@uri + @book_id), RDF::type, :type])
      #puts query.to_s
      solutions = repo.select(query)
      solutions.bindings[:type].first.should eql(RDF::BIBO.Document)
    end
    
    it "should support updating a book while preserving harvested info" do
      preserve = ["FOAF.depiction", "REV.hasReview"]
      response = OAIUpdate.sparql_update(@book_id, :preserve => preserve)
      #p response
      response.should match(/(done|nothing)/)
      response.should_not match(/NULL/)
    end
    
    it "should support deleting a book entirely" do
      response = OAIUpdate.sparql_purge(@book_id)
      response.should match(/(done|nothing)/)
      response.should_not match(/NULL/)
    end
  end
end
