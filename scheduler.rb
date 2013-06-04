#encoding: utf-8
# Scheduler Server 
#$stdout.sync = true
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
    
    job_id = self.scheduler.at params[:start_time], :tags => [{:id => params[:id], :tags => params[:tags]}] do
      10.times do
        puts "testing..."
        sleep 1
      end
    end
  end
  
  def test_atjob(atjob, params={})
    params[:start_time] ||= Time.now
    params[:tags]       ||= "dummyjob"
    job_id = self.scheduler.at params[:start_time], :tags => [{:tags => params[:tags]}] do
      puts "testing atjob: #{atjob}"
      sleep 3
    end
  end

  def test_cronjob(cronjob, params={})
    params[:frequency]  ||= "0 * * * *"
    params[:tags]       ||= "dummyjob"
    job_id = self.scheduler.cron params[:frequency], :tags => [{:tags => params[:tags]}] do
      puts "testing cronjob: #{cronjob}"
      sleep 3
    end
  end

  ### ISQL rules ###
  def run_isql_rule(rule)
    return nil unless rule.id and rule.script and rule.start_time
    rule.tag        ||= "dummyrule"
    # for now rescue empty timestamp to Time.now
    begin
      start_time = Time.parse("#{rule.start_time}")
    rescue 
      start_time = Time.now
    end
    job_id = self.scheduler.at start_time, :tags => [{:id => rule.id, :library => rule.library, :tags => rule.tag}] do |job|
      timing_start = Time.now
      logger.info "Running rule: #{rule.id}"
      logger.info "Script:\n#{rule.script}"
      rule.last_result = %x[(echo "#{rule.script.to_s}") | /usr/bin/isql-vt 1111 #{REPO.username} #{REPO.password} VERBOSE=ON BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout ]
      logger.info "Time to complete: #{Time.now - timing_start} s."
      logger.info "Result:\n#{rule.last_result}"
      logline = {:time => Time.now, :rule => rule.id, :job_id => job.job_id, :cron_id => nil, :library => rule.library, :start_time => timing_start, 
                 :length => "#{Time.now - timing_start} s.", :tags => rule.tag, :result => rule.last_result}
      write_history(logline)
    end
  end

  def schedule_isql_rule(rule)
    return nil unless rule.id and rule.script and rule.frequency
    rule.tag ||= "dummyrule"
    cron_id = self.scheduler.cron rule.frequency, :tags => [{:id => rule.id, :library => rule.library, :tags => rule.tag}] do |cron|
      timing_start = Time.now
      logger.info "Running scheduled rule: #{rule.id}"
      logger.info "Script:\n #{rule.script}"
      rule.last_result = %x[(echo "#{rule.script.to_s}") | /usr/bin/isql-vt 1111 #{REPO.username} #{REPO.password} VERBOSE=ON BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout ]
      logger.info "Time to complete: #{Time.now - timing_start} s."
      logger.info "Result:\n#{rule.last_result}"
      logline = {:time => Time.now, :rule => rule.id, :job_id => nil, :cron_id => cron.job_id, :library => rule.library, :start_time => timing_start, 
                 :length => "#{Time.now - timing_start} s.", :tags => rule.tag, :result => rule.last_result}
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

  # patched scheduler to allow finding job by tag
  def find_jobs_by_tag(t)
    #jobs = self.scheduler.find_by_tag({:tags => t})
    jobs = self.scheduler.all_jobs.values.select { |j| j.tags[0][:tags].include?(t) }
    logger.info "all jobs by tag: #{jobs}"
    jobs
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
            
  ### Specific AtJobs based on Library updates ###
  ### OAI harvest jobs ###
  
  # The full cycle of an OAI harvest: 
  # 1) pull records from OAI-PMH repo
  # 2) convert harvested records, based on Library's chosen mapping
  #   2a) write converted records to ntriples file if chosen
  #   2b) update RDF store directly through SPARQL Update, deleting deleted records and updates records not touching preserved attributes
  #   2c) if any harvesters are activated for library, do external harvesting and update RDF store
  # 3) return to 1) for next OAI batch by resumption token 
  # 4) if any rules are activated for library, run rules directly on library graph
    
  def start_oai_harvest(params={})
    # for now rescue empty timestamp to Time.now
    params[:from]  = Time.parse(params[:from]).strftime("%F") rescue Date.today.prev_day.to_s
    params[:until] = Time.parse(params[:until]).strftime("%F") rescue Date.today.to_s
    
    start_time = Time.parse("#{params[:start_time]}") rescue Time.now
    params[:tags]          ||= "oaiharvest"
    library = Library.new.find(:id => params[:id].to_i)
    logger.info "Scheduled params: #{params}"
    job_id = self.scheduler.at start_time, :tags => [{:library => library.id, :tags => params[:tags]}] do |job|
      timing_start = Time.now
      # result counters
      @countrecords, @deletecount, @modifycount, @harvestcount = 0, 0, 0, 0
      logger.info "library oai: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["redirects"],
        :set => library.oai["set"])
      # do the OAI dance!
      run_oai_harvest_cycle(oai, library, params)    
      
      length = Time.now - timing_start
      logline = {:time => Time.now, :job_id => job.job_id, :cron_id => nil, :library => library.id, :start_time => start_time, 
                 :length => "#{length} s.", :tags => params[:tags], 
                 :result => "Total records modified: #{@countrecords}.\nRecords deleted: #{@deletecount}\nRecords modified: #{@modifycount}\nTriples harvested: #{@harvestcount}"}
      write_history(logline)
      logger.info "Time to complete oai harvest: #{length} s.\n-------\nTotal records modified: #{@countrecords}.\nRecords deleted: #{@deletecount}\nRecords modified: #{@modifycount}\nTriples harvested: #{@harvestcount}"
    end
  end
  
  private 
  # internal functions
  
  def run_oai_harvest_cycle(oai, library, params={})
    # 1) pull first records from OAI-PMH repo
    oai.query :from => params[:from], :until => params[:until]
    @countrecords += oai.records.count  
    # 2)
    convert_oai_records(oai.records, library, params)
    # 3) do the resumption loop...
    until oai.response.resumption_token.nil? or oai.response.resumption_token.empty?
      # fetch remainder if resumption token
      # 1)
      oai.query :resumption_token => oai.response.resumption_token if oai.response.resumption_token
      @countrecords += oai.records.count
      # 2)
      convert_oai_records(oai.records, library, params)
    end
    # 4) Finally run activated rules on updated RDFstore
    logger.info "Running rules on updated set..."
    run_rules_engine(library) if library.rules.any?
  end
  
  def convert_oai_records(oairecords, library, params={})
    timing_start = Time.now
    @rdfrecords = []
    # 2) convert harvested records, based on Library's chosen mapping
    oairecords.each do |record| 
      unless record.deleted?
        
        # hack to add marc namespace to first element of metadata in case of namespace issues
        record.metadata[0].add_namespace("marc", "info:lc/xmlns/marcxchange-v1")
        
        xmlreader = MARC::XMLReader.new(StringIO.new(record.metadata[0].to_s)) 
        xmlreader.each do |marcrecord|
          rdf = RDFModeler.new(library.id, marcrecord)
          rdf.set_type(library.config['resource']['type'])        
          rdf.convert
          # the conversion, rules, harvesting and updating
          write_record_to_file(rdf, library, params)   if params[:write_records]  # a)
          update_record(rdf, library, params)          if params[:sparql_update]  # b)
          run_external_harvester(rdf, library, params) # c)
          @rdfrecords << rdf.statements
          @modifycount += 1
        end
      else
        deletedrecord = record.header.identifier.split(':').last
        update_record(deletedrecord, library, :delete => true) if params[:sparql_update] # schedule writing to repository
        @deletecount += 1
        #puts "deleted record: #{deletedrecord}"
      end
    end
    logger.info "Time to convert #{oairecords.count} records: #{Time.now - timing_start} s."
  end
  
  # 2a) write converted records to ntriples file if chosen
  def write_record_to_file(rdf, library, params={})
    file = File.open(File.join(File.dirname(__FILE__), "./db/converted", "#{params[:from]}_to_#{params[:until]}_#{library.name}.nt"), 'a+')
    file.write(RDFModeler.write_ntriples(rdf.statements)) if file
  end

  # 2b) update RDF store directly through SPARQL Update, deleting deleted records and updates records not touching preserved attributes
  def update_record(rdf, library, params={})
    s = SparqlUpdate.new(rdf, library)
    params[:delete] ? s.delete_record : s.modify_record
  end

  # 2c) if any harvesters are activated for library, do external harvesting and update RDF store
  def run_external_harvester(rdf, library, params={})
    library.harvesters.each do |h|
      # find harvester
      harvester = Harvest.new.find :id=>h['id']
      return nil unless harvester
      # need to query converted records through temporary graph to make RDF::Query::Solutions for batch harvesting
      # make temporary graph with converted record
      tempgraph = RDF::Graph.new('temp')
      rdf.statements.each {|s| tempgraph << s }
      # query for :edition and :object
      batchsolutions = RDF::Query.execute(tempgraph) do
        pattern [:edition, RDF.type, RDF.module_eval("#{library.config['resource']['type']}") ]
        pattern [:edition, RDF.module_eval("#{harvester.local['predicate']}"), :object ]
      end
      logger.info "Batch Harvest solutions #{batchsolutions.inspect}"
      if harvester.local['subject'] == 'work'
        # TODO!
        # if harvester subject is set to 'work' then a RDFstore lookup must be made to get work URI
      else
        # just say work = edition for now
        batchsolutions.each{|s| s.merge!(RDF::Query::Solution.new(:work => batchsolutions.first.edition))}
      end
      
      # then harvest
      bh = BatchHarvest.new harvester, batchsolutions
      bh.start_harvest
      next if bh.statements.empty?
      logger.info "Batch Harvest results #{bh.statements.inspect}"
      # and insert harvested triples into RDF store
      SparqlUpdate.insert_harvested_triples(library.config['resource']['default_graph'], bh.statements)
      @harvestcount += bh.statements.count
    end
  end

  # 4) run rules on library graph
  def run_rules_engine(library)
    library.rules.each do |r|
      rule = Rule.new.find :id=>r['id']
      # make sure rule is localized and safe/sanitized before running!
      rule.localize(library)
      rule.library = library.id
      rule.sanitize
      run_isql_rule(rule) if rule
    end
  end
end

unless ENV['RACK_ENV'] == 'test'
  #$SAFE = 1   # disable eval() and friends
  DRb.start_service DRBSERVER, Scheduler.new
  DRb.thread.join
end

# loads all saved schedules if Scheduler is restarted and in production mode
if ENV['RACK_ENV'] == 'production'
  #Libraries.all
end
