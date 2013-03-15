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
      @scheduler = Scheduler.new
    end
    
    it "starts a Rufus::Scheduler::AtJob object" do
      job_id = @scheduler.test_atjob(@rule[:script], :start_time => @rule[:start_time], :tags => [@rule[:id], @rule[:tag]])
      job_id.should be_a(Rufus::Scheduler::AtJob)
      job_id.t.should == @time
      job_id.params[:tags][0].should == @rule[:id]
      job_id.params[:tags][1].should == @rule[:tag]
    end    

    it "schedules a started Rufus::Scheduler::CronJob" do
      cron_id = @scheduler.test_cronjob(@rule[:script], :frequency => @rule[:frequency], :tags => [@rule[:id], @rule[:tag]])
      cron_id.should be_a(Rufus::Scheduler::CronJob)
      cron_id.cron_line.original.should == @rule[:frequency]
      cron_id.params[:tags][0].should == @rule[:id]
      cron_id.params[:tags][1].should == @rule[:tag]
    end
    
    it "schedules rule job directly" do
      job_id = @scheduler.run_rule(@rule)
      job_id.trigger_block.should match(/10 Rows/)
    end   
    
    it "finds job by tags" do
      job_id = @scheduler.run_rule(@rule)
      @scheduler.find_jobs_by_tag('A dummy tag').should_not be_empty
    end   
  end
end
