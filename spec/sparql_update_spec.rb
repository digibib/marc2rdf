require File.join(File.dirname(__FILE__), 'spec_helper')
describe SparqlUpdate do

  context "when doing a SPARQL UPDATE from converted MARC" do
    before(:each) do
      @reader = MARC::ForgivingReader.new("./spec/example.binary.normarc.mrc")
      record = @reader.first
      rdf = RDFModeler.new(1, record)
      rdf.set_type("BIBO.Document")
      rdf.convert
      @default_graph = 'http://example.com'
      l = {'id'=>1, 'name'=>'test', 'mapping'=>'dummy', 'oai'=>{'preserve_on_update'=>['FOAF.depiction']}, 
          'config'=>{'resource'=>{'default_graph'=> @default_graph}}}
      library = l.to_struct("Library")
      @sparql = SparqlUpdate.new(rdf,library)
    end
    
    it "should support creating an update query from record" do
      @sparql.uri.to_s.should == "http://example.com/id_0583095"
    end

    it "should preserve predicate when update query from record" do
      @sparql.preserve.should == ['FOAF.depiction']
    end
    
    # test private methods
    it "should create proper delete query with minus" do
      result = @sparql.send(:delete_old_record)
      result.should == 'DEFINE sql:log-enable 2 DELETE FROM <http://example.com> { <http://example.com/id_0583095> ?p ?o . } WHERE { <http://example.com/id_0583095> ?p ?o . MINUS { <http://example.com/id_0583095> <http://xmlns.com/foaf/0.1/depiction> ?o . } }'
    end
    
    it "should delete existing authorities before update" do
      result = @sparql.send(:delete_old_authorities)
      result.first['id'].to_s.should == "http://data.deichman.no/person/x32026400"
    end
    
    it "should insert new statements" do
      result = @sparql.send(:insert_new_record)
      result.should match('INSERT DATA INTO GRAPH <http://example.com> { <http://example.com/id_0583095>')
    end

    it "should purge a record" do
      result = @sparql.send(:purge_record)
      result.should == 'DEFINE sql:log-enable 2 DELETE FROM <http://example.com> { <http://example.com/id_0583095> ?p ?o . ?x ?y <http://example.com/id_0583095> . } WHERE { <http://example.com/id_0583095> ?p ?o . ?x ?y <http://example.com/id_0583095> . }'
    end
  end
end
