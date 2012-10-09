require File.join(File.dirname(__FILE__), 'spec_helper')

describe Sparql do

  before(:all) do
    @sparql_endpoint   = "http://localhost:8890/sparql"
    @sparul_endpoint   = "http://localhost:8890/sparql-auth"
    @uri = "http://example.com/"
    @repo = RDF::Virtuoso::Repository
  end
  
  context "when connecting to a triplestore" do
    it "should support connecting to a SPARQL endpoint" do
      repo = @repo.new(@sparql_endpoint)
    end
  end
  
  context "when doing a SPARQL query against repository" do
    before(:all) do
      @query = RDF::Virtuoso::Query
      #$debug = true
    end
    
    it "should support counting a RDF.type" do
      type = RDF::BIBO.Document
      response = Sparql.count(type)
      response.should be_kind_of(Integer)
    end

    it "should support looking up isbns with OFFSET and LIMIT" do
      response = Sparql.rdfstore_isbnlookup(:offset => 10, :limit => 50)
      response.first[:book].should be_kind_of(RDF::URI)
      response.first[:work].should be_kind_of(RDF::URI)
      response.first[:isbn].should be_kind_of(RDF::Literal)
    end    
  end
end
