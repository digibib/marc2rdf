require File.join(File.dirname(__FILE__), 'spec_helper')
describe Harvest do
  context "when creating harvester rules" do
    before(:each) do
      @harvest = Harvest.new
    end
    it "should create a harvester rule with a name and description" do
      @harvest.create(:name => "Test harvester", :description => "A rule testing harvester")
      @harvest.name.should == "Test harvester"
      @harvest.description.should == "A rule testing harvester"
    end
    
    it "should give rule an unique id" do
      @harvest.create(:tag => "Test rule tag", :id => "A dummy id")
      @harvest.id.should_not == "A dummy id"
    end
    
    it "should not allow to update unique id" do
      @harvest.create(:name => "Test harvest")
      @harvest.update(:id=>"New dummy id")
      @harvest.id.should_not == "New dummy id"
      @harvest.delete
    end    
  end
  
end
