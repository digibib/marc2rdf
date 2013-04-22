#encoding: utf-8
# Scheduler Server 
$stdout.sync = true
require_relative "./config/init.rb"
require 'logger' 
require 'eventmachine'

Scheduler = Struct.new(:scheduler)
class Scheduler
  # start a Rufus::Scheduler object if not already done
  def initialize
    self.scheduler ||= Rufus::Scheduler.start_new
  end
  
  def logger
    logger = Logger.new(File.expand_path("../logs/scheduler_#{ENV['RACK_ENV']}.log", __FILE__))
  end  
  
  ### dummy jobs for testing ###
  def dummyjob(params={})
    params[:id]         ||= SecureRandom.uuid
    params[:start_time] ||= Time.now
    params[:tags]       ||= "dummyjob"
    
    job_id = self.scheduler.at params[:start_time], :tags => [params[:id], params[:tags]] do
      10.times do
        puts "testing..."
        sleep 1
      end
    end
  end
  
  def test_atjob(atjob, params={})
    params[:start_time] ||= Time.now
    params[:tags]       ||= "dummyjob"
    job_id = self.scheduler.at params[:start_time], :tags => params[:tags] do
      puts "testing atjob: #{atjob}"
      sleep 3
    end
  end

  def test_cronjob(cronjob, params={})
    params[:frequency]  ||= "0 * * * *"
    params[:tags]       ||= "dummyjob"
    job_id = self.scheduler.cron params[:frequency], :tags => params[:tags] do
      puts "testing cronjob: #{cronjob}"
      sleep 3
    end
  end

  ### ISQL rules ###
  # TODO: inject rules run to json log
  def run_isql_rule(rule)
    return nil unless rule.id and rule.script and rule.start_time
    rule.tag        ||= "dummyrule"
    rule.start_time ||= Time.now + 30 # default to 30 sec. from now
    job_id = self.scheduler.at rule.start_time, :tags => [rule.id, rule.library, rule.tag] do |job|
      timing_start = Time.now
      logger.info "Running rule: #{rule.id}"
      logger.info "Script:\n#{rule.script}"
      rule.last_result = %x[(echo "#{rule.script.to_s}") | /usr/bin/isql-vt 1111 #{REPO.username} #{REPO.password} VERBOSE=ON BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout ]
      logger.info "Time to complete: #{Time.now - timing_start} s."
      logger.info "Result:\n#{rule.last_result}"
      logline = {:time => Time.now, :rule => rule.id, :job_id => job.job_id, :cron_id => nil, :library => rule.library, :start_time => timing_start, :length => "#{Time.now - timing_start} s.", :result => rule.last_result}
      write_history(logline)
    end
  end

  def schedule_isql_rule(rule)
    return nil unless rule.id and rule.script and rule.frequency
    rule.tag ||= "dummyrule"
    cron_id = self.scheduler.cron rule.frequency, :tags => [rule.id, rule.library, rule.tag] do |cron|
      timing_start = Time.now
      logger.info "Running scheduled rule: #{rule.id}"
      logger.info "Script:\n #{rule.script}"
      rule.last_result = %x[(echo "#{rule.script.to_s}") | /usr/bin/isql-vt 1111 #{REPO.username} #{REPO.password} VERBOSE=ON BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout ]
      logger.info "Time to complete: #{Time.now - timing_start} s."
      logger.info "Result:\n#{rule.last_result}"
      logline = {:time => Time.now, :rule => rule.id, :job_id => nil, :cron_id => cron.job_id, :library => rule.library, :start_time => timing_start, :length => "#{Time.now - timing_start} s.", :result => rule.last_result}
      write_history(logline)
    end
  end
  
  def pause(job)
    self.scheduler.pause(job)
  end

  def resume(job)
    self.scheduler.resume(job)
  end
    
  def unschedule(cronjob)
    self.scheduler.unschedule(cronjob)
  end
  
  ### find jobs ###
  def find_running_jobs
    jobs = self.scheduler.running_jobs
    logger.info "running jobs: #{jobs}"
    jobs
  end
  
  def find_scheduled_jobs
    jobs = self.scheduler.jobs
    logger.info "scheduled jobs: #{jobs}"
    jobs
  end

  def find_cronjobs
    jobs = self.scheduler.cron_jobs
    logger.info "scheduled cron jobs: #{jobs}"
    jobs
  end
  
  def find_all_jobs
    jobs = self.scheduler.all_jobs
    logger.info "all jobs: #{jobs}"
    jobs
  end

  def find_jobs_by_tag(t)
    jobs = self.scheduler.find_by_tag(t)
    logger.info "all jobs by tag: #{jobs}"
    jobs
  end
          
  ### Specific AtJobs based on Library updates ###
  ### OAI harvest jobs ###
  
  def start_oai_harvest(params={})
    params[:start_time] ||= Time.now 
    params[:tags]        ||= "oaiharvest"
    job_id = self.scheduler.at params[:start_time], :tags => params[:tags] do
      timing_start = Time.now
      
      library = Library.new.find(:id => params[:id].to_i)
      logger.info "library oai: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["redirects"])
      oai.query(:from => params[:from], :until => params[:until])
      convert_oai_records(oai.records, library)
      # do the resumption loop...
      while(oai.response.resumption_token and not oai.response.resumption_token.empty?)
        oai.records = []
        oai.query(:resumption_token => oai.response.resumption_token)
        oai.response.each {|r| oai.records << r }
        convert_oai_records(oai.records, library)
      end
  
      logger.info "Time to complete oai harvest: #{Time.now - timing_start} s."
    end
  end
  
  def convert_oai_records(oairecords, library)
    job_id = self.scheduler.at Time.now , :tags => "conversion" do
      timing_start = Time.now
      rdfrecords = []
      oairecords.each do |record| 
        unless record.deleted?
          xmlreader = MARC::XMLReader.new(StringIO.new(record.metadata.to_s)) 
          xmlreader.each do |marc|
            rdf = RDFModeler.new(library.id, marc)
            rdf.set_type(library.config['resource']['type'])        
            rdf.convert
            write_record_to_file(rdf, library) # schedule writing to file
            update_record(rdf, library)        # schedule writing to repository
            rdfrecords << rdf.statements
          end
        else
          puts "deleted record: #{record.header.identifier.split(':').last}"
        end
      end
      logger.info "Time to convert #{rdfrecords.count} records: #{Time.now - timing_start} s."
    end
  end
  
  # write converted record to file
  def write_record_to_file(rdf, library)
    job_id = self.scheduler.at Time.now , :tags => "saving" do
      FileUtils.mkdir_p File.join(File.dirname(__FILE__), 'db', "#{library.id}")
      file = File.open(File.join(File.dirname(__FILE__), 'db', "#{library.id}", 'test.nt'), 'a+')
      rdf.write_record
      file.write(rdf.rdf)
    end
  end

  # sparql update converted record
  def update_record(rdf, library)
    job_id = self.scheduler.at Time.now , :tags => "SparqlUpdate" do
      # TODO
    end
  end
    
  ### History 
  def read_history
    logfile = File.join(File.dirname(__FILE__), 'logs', 'history.json')
    open(logfile, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse({"history"=>[]}.to_json)))} unless File.exist?(logfile)
    log = JSON.parse(IO.read(logfile))
  end
  
  def write_history(logline)
    logfile = File.join(File.dirname(__FILE__), 'logs', 'history.json')
    log = self.read_history
    log["history"] << logline
    open(logfile, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(log.to_json))) } 
  end
  
end

unless ENV['RACK_ENV'] == 'test'
  #$SAFE = 1   # disable eval() and friends
  DRb.start_service DRBSERVER, Scheduler.new
  DRb.thread.join
end
