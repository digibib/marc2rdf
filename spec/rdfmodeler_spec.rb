require File.join(File.dirname(__FILE__), 'spec_helper')
describe RDFModeler do

  context "when converting MARC (binary) file to RDF" do
    before(:each) do
      @reader     = MARC::ForgivingReader.new("./spec/example.binary.normarc.mrc")
    end
    
    it "should support creating a RDF record from an binary MARC record" do
      r = RDFModeler.new(1, @reader.first)
      r.library_id.should == 1
    end
    
    it "should support converting a MARC record to RDF" do
      record = @reader.first
      r = RDFModeler.new(1, record)
      r.set_type("BIBO.Document")
      r.convert
      r.statements.count.should >= 1
    end
        
  end
  
  context "advanced RDF modelling and mapping" do
    before(:each) do
      base = 'http://data.deichman.no/resource/'
      l = {'id'=>1, 'name'=>'test', 
          'config'=>{'resource'=>{'base' => base, 'prefix' => 'tnr_', 'identifier_tag' => '001'}}}
      @library = l.to_struct("Library")
      @marcxml = MARC::XMLReader.new("./spec/example.normarc.xml")
      template = File.join(File.dirname(__FILE__), '..', 'config', 'templates', 'mappings.json')
      json = JSON.parse(IO.read(template))
      @map = json.first.to_struct("Mapping")
    end

    it "allows alternative mapping as param" do
      r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
      r.map.name.should == "Example Mapping"
    end

    it "allows a modified mapping as param" do
      @map.mapping["tags"]["020"] = {
        "subfield" => {
          "a" => {
            "predicate" => "BIBO.isbn", 
            "object" => {
              "datatype" => "literal"
            }
          }
        }
      }
      r = RDFModeler.new(@library, @marcxml.first, :mapping => @map)
      r.convert
      r.statements.to_s.should include("http://purl.org/ontology/bibo/isbn")
    end
  end

end
