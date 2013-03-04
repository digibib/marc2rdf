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
  
  def dummyjob(params={})
    params[:start_time] ||= Time.now
    params[:tag]        ||= "dummyjob"    
    job_id = self.scheduler.at params[:start_time], :tags => params[:tag] do
      10.times do
        puts "testing..."
        sleep 3
      end
    end
  end
  
  ### OAI harvest jobs ###
  
  def start_oai_harvest(params={})
    params[:start_time] ||= Time.now 
    params[:tag]        ||= "oaiharvest"
    job_id = self.scheduler.at params[:start_time], :tags => params[:tag] do
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
        #oai.response = oai.client.list_records(:resumption_token => oai.response.resumption_token)
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
            write_record(rdf, library) # schedule writing
            rdfrecords << rdf.statements
          end
        else
          puts "deleted record: #{record.header.identifier.split(':').last}"
        end
      end
      logger.info "Time to convert #{rdfrecords.count} records: #{Time.now - timing_start} s."
    end
  end
  
  def write_record(rdf, library)
    job_id = self.scheduler.at Time.now , :tags => "saving" do
      FileUtils.mkdir_p File.join(File.dirname(__FILE__), 'db', "#{library.id}")
      file = File.open(File.join(File.dirname(__FILE__), 'db', "#{library.id}", 'test.nt'), 'a+')
      rdf.write_record
      file.write(rdf.rdf)
    end
  end
  # start schedule, default every five minutes
  def schedule(cron, params={})
    params[:frequency] ||= "*/5 * * * *"
    params[:tag]       ||= "test"
    cron_id = self.scheduler.cron params[:frequency], :tags => params[:tag] do 
      puts cron if cron # run script here
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
  
  # returns a map job_id => job of at/in/every jobs  
  def find_running_jobs
    jobs = self.scheduler.running_jobs
    logger.info "running jobs: #{jobs}"
    jobs
  end
  
  def find_jobs
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
  
end

#$SAFE = 1   # disable eval() and friends

DRb.start_service DRBSERVER, Scheduler.new
DRb.thread.join
