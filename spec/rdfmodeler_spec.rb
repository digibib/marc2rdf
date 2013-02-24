require File.join(File.dirname(__FILE__), 'spec_helper')
describe RDFModeler do

  context "when converting MARC binary file to RDF" do
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
  

end
