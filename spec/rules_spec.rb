require File.join(File.dirname(__FILE__), 'spec_helper')
describe Rule do
  context "when creating rules" do
    before(:each) do
      @rule = Rule.new
    end
    it "should create a rule with a name and description" do
      @rule.create(:name => "Test rule", :description => "A rule testing rules")
      @rule.name.should == "Test rule"
      @rule.description.should == "A rule testing rules"
    end
    
    it "should create a rule with a tag and script to run" do
      @rule.create(:tag => "Test rule tag", :script => "A dummy script")
      @rule.tag.should == "Test rule tag"
      @rule.script.should == "A dummy script"
    end

    it "should give rule an unique id and give a default DateTime start" do
      @rule.create(:tag => "Test rule tag", :id => "A dummy id")
      @rule.id.should_not == "A dummy id"
      @rule.start_time.should be_a(DateTime)
    end
    
    it "should not allow to update unique id" do
      @rule.create(:name => "Test rule")
      @rule.update(:id=>"New dummy id")
      @rule.id.should_not == "New dummy id"
    end    
  end
  
  context "when activating rules" do
    before(:each) do
      @time = Time.now + 60*10 # now + 10mins
      @script = "SPARQL SELECT * WHERE {[] a ?Concept} LIMIT 10 ;"
      @rule = Rule.new.create(
        :name => "Test rule", 
        :description => "A rule testing rules",
        :tag => "A dummy tag",
        :start_time => @time,
        :frequency => "00 01 * * *",
        :script => @script
        )
    end
    
    it "starts a Rufus::Scheduler::AtJob object" do
      @rule.activate
      @rule.job.should be_a(Rufus::Scheduler::AtJob)
      @rule.job.t.should == "#{@time}"
    end    

    it "schedules a started Rufus::Scheduler::AtJob" do
      @rule.activate
      @rule.schedule
      @rule.job.t.should == "#{@time}"
      @rule.job.scheduler.cron_jobs.should_not == nil
    end
    
    it "schedules given script in Rufus::Scheduler::CronJob" do
      @rule.schedule
      @rule.cronjob.should_not == nil
    end   
    
    it "finds job by tags" do
      @rule.activate
      @rule.find_jobs_by_tag('A dummy tag').should_not be_empty
    end   
  end
end
