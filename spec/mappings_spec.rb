require File.join(File.dirname(__FILE__), 'spec_helper')
describe Mapping do
  context "when creating mapping" do
    before(:each) do
      @mapping = Mapping.new
    end
    it "should create a mapping with a name and description" do
      @mapping.create(:name => "Test mapping", :description => "A mapping test")
      @mapping.name.should == "Test mapping"
      @mapping.description.should == "A mapping test"
    end
    
    it "should give rule an unique id and give a default DateTime start" do
      @mapping.create(:name => "Test mapping", :id => "A dummy id")
      @mapping.id.should_not == "A dummy id"
    end
    
    it "should not allow to save empty mapping" do
      @mapping.create(:name => "Test mapping")
      @mapping.save.should be_nil
    end

    it "should not allow to save invalid mapping" do
      @mapping.create(:name => "Test mapping",
                      :mapping => "[ { \"tags\": { \"100\" }")
      @mapping.save.should be_nil
    end
    
    it "should not allow to update unique id" do
      @mapping.create(:name => "Test mapping")
      @mapping.update(:id=>"New dummy id")
      @mapping.id.should_not == "New dummy id"
    end    
  end
  
end
