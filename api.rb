#!/usr/bin/env ruby 
#encoding: utf-8
$stdout.sync = true

require_relative "./config/init.rb"

# access scheduler through drb socket
unless ENV['RACK_ENV'] == 'test'
  DRb.start_service
  Scheduler = DRbObject.new_with_uri DRBSERVER
end
# trap all exceptions and fail gracefuly with a 500 and a proper message
class ApiErrorHandler < Grape::Middleware::Base
  def call!(env)
    @env = env
    begin
      @app.call(@env)
    rescue Exception => e
      throw :error, :message => e.message || options[:default_message], :status => 500
    end
  end  
end

# custom option validator :length
class Length < Grape::Validations::SingleOptionValidator
  def validate_param!(attr_name, params)
    unless params[attr_name].length >= @option
      throw :error, :status => 400, :message => "#{attr_name}: must be at the most #{@option} characters long"
    end
  end
end

class API < Grape::API
  helpers do
    def logger
      logger = Logger.new(File.expand_path("../logs/#{ENV['RACK_ENV']}.log", __FILE__))
    end
  end
  
  prefix 'api'
  format :json
  default_format :json
  use ApiErrorHandler
  
  before do
    # Of course this makes the request.body unavailable afterwards.
    # You can just use a helper method to store it away for later if needed. 
    logger.info "#{env['REMOTE_ADDR']} #{env['HTTP_USER_AGENT']} #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} -- Request: #{request.body.read}"
  end

  # Rescue and log validation errors gracefully
  rescue_from Grape::Exceptions::ValidationError do |e|
    logger = Logger.new(File.expand_path("../logs/#{ENV['RACK_ENV']}.log", __FILE__))
    logger.error "#{e.message}"
    Rack::Response.new({
        'status' => e.status,
        'message' => e.message,
        #'param' => e.param,
    }.to_json, e.status) 
  end
    
  resource :library do
    desc "returns all libraries or specific library"
    get "/" do
      content_type 'json'
      unless params[:id]
        { :libraries => Library.new.all }
      else
        logger.info params
        library = Library.new.find(params)
        error!("No library with id: #{params[:id]}", 404) unless library
        { :library => library }        
      end
    end
    
    ### Mapping ###
     
    desc "get specific library mapping"
    get "/:id/mapping" do
      content_type 'json'
      library = Library.new.find(:id=> params[:id].to_i)
      if library
        { :mapping => library.mapping }
      else
        logger.error "library mapping not found"   
        error!("library mapping not found", 400)
      end
    end
    
    desc "create new library"
      params do
        requires :name,       type: String, length: 5, desc: "Name of library"
        optional :config,     desc: "Config file"
        optional :mapping,    desc: "Mapping file"
        optional :oai,        desc: "OAI settings"
        optional :harvesting, desc: "Harvesting settings file" 
      end
    post "/" do
      content_type 'json'
      library = Library.new.create(params)
      library.save
      logger.info "POST: params: #{params} - created library: #{library}"
      { :library => library }
    end
    
    desc "save specific library mapping"
      params do
        requires :mapping, desc: "Mapping file"
      end
    put "/:id/mapping" do
      content_type 'json'
      logger.info "PUT: mapping: #{params[:mapping]}"
      library = Library.new.find(:id => params[:id].to_i)
      puts params
      library.update(:mapping => params[:mapping])
      logger.info "PUT: params: #{params} - updated mapping: #{library.mapping}"
      { :mapping => library.mapping }
    end
            
    ### Conversion ###
    desc "convert records"
    get "/:id/convert" do
      content_type 'json'
      library = Library.new.find(:id => params[:id])
      { :record => record }
    end
  
    desc "edit/update library"
      params do
        requires :id,         type: Integer, desc: "ID of library"
        optional :name,       type: String,  length: 5, desc: "Name of library"
        optional :config,     desc: "Config file"
        optional :mapping,    desc: "Mapping file"
        optional :oai,        desc: "OAI settings"
        optional :harvesting, desc: "Harvesting settings file" 
      end
    put "/" do
      content_type 'json'
      valid_params = ['id','name','config','mapping','oai','harvesting']
      # do we have a valid parameter?
      if valid_params.any? {|p| params.has_key?(p) }
        library = Library.new.find(:id => params[:id])
        library.update(params)
        logger.info "updated library: #{library}"
        { :library => library}
      else
        logger.error "invalid or missing params"   
        error!("Need at least one param of id|name|config|mapping|oai|harvesting", 400)      
      end
    end
    
    desc "delete a library"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    delete "/" do
      content_type 'json'
      library = Library.new.find(:id => params[:id])
      library.delete
      logger.info "DELETE: params: #{params} - deleted library: #{library}"
      { :library => library }
    end
  end # end library namespace
  
  resource :mapping do
    desc "return mapping template or id"
    get "/" do
      content_type 'json'
      mapping = JSON.parse(IO.read(File.join(File.dirname(__FILE__), 'config/templates', 'mapping_skeleton.json')))
      { :mapping => mapping }
    end
  end # end mapping namespace

  resource :convert do
    desc "test convert resource"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    put "/test" do
      content_type 'json'
      library = Library.new.find(:id => params[:id])
      reader = MARC::XMLReader.new('./spec/example.normarc.xml')
      record = Marshal.load(Marshal.dump(reader.first))
      rdf = RDFModeler.new(library.id, record)
      rdf.convert
      { :resource => rdf.statements }
    end
  end # end mapping namespace
  
  resource :oai do
    desc "validate a OAI repository"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    get "/validate" do
      content_type 'json'
      library = Library.new.find(:id => params[:id].to_i)
      logger.info "library: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["timeout"])
      result = oai.validate
      { :result => result }
    end 

    desc "identify a OAI repository"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    get "/identify" do
      content_type 'json'
      library = Library.new.find(:id => params[:id].to_i)
      logger.info "library: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["timeout"])
      result = oai.client.identify
      { :result => result }
    end 
        
    desc "harvest a record batch"
      params do
        requires :id,         type: Integer,  desc: "ID of library"
        optional :from,       type: DateTime, desc: "From Date"
        optional :until,      type: DateTime, desc: "To Date"
        optional :start_time, type: Time,     desc: "Time to schedule"
        optional :tag,        type: String,   desc: "Tag string"
      end
    put "/harvest" do
      content_type 'json'
      result = Scheduler.start_oai_harvest :id => params[:id].to_i,
          :from  => params[:from]  ||= Date.today.prev_day.to_s,
          :until => params[:until] ||= Date.today.to_s
      { :result => result }
    end 

    desc "saves a record batch"
      params do
        requires :id,    type: Integer, desc: "ID of library"
        optional :from,  type: DateTime, desc: "From Date"
        optional :until, type: DateTime, desc: "To Date"
      end
    put "/save" do
      content_type 'json'
      library = Library.new.find(:id => params[:id].to_i)
      logger.info "library: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["redirects"])
      oai.query(:from => params[:from], :until => params[:until])
      logger.info "oai response: #{oai.response}"
      FileUtils.mkdir_p File.join(File.dirname(__FILE__), 'db', "#{library.id}")
      file = File.open(File.join(File.dirname(__FILE__), 'db', "#{library.id}", 'test.nt'), 'w')
      oai.response.entries.each do |record| 
        unless record.deleted?
          xmlreader = MARC::XMLReader.new(StringIO.new(record.metadata.to_s)) 
          xmlreader.each do |marc|
            rdf = RDFModeler.new(library.id, marc)
            rdf.set_type("BIBO.Document")        
            rdf.convert
            file.write(rdf.statements)
          end
        else
          logger.info "deleted record: #{record.header.identifier.split(':').last}"
        end
      end
      { :result => "saved!" }
    end
  
    desc "identify a OAI repository"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    get "/identify" do
      content_type 'json'
      library = Library.new.find(:id => params[:id].to_i)
      logger.info "library: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["timeout"])
      result = oai.client.identify
      { :result => result }
    end 
  end # end oai namespace

  resource :scheduler do
    desc "all jobs"
    get "/" do
      content_type 'json'
      jobs = Scheduler.find_all_jobs
      { :jobs => jobs }
    end
    
    # list running jobs
    desc "running jobs"
    get "/running_jobs" do
      content_type 'json'
      result = Scheduler.find_running_jobs
      jobs = []
      result.each do |job|
        jobs.push({:job_id    => job.job_id,
                  :scheduler => job.scheduler,
                  :start_time => job.t,
                  :last_job_thread => job.last_job_thread,
                  :params => job.params,
                  :block => job.block,
                  :schedule_info => job.schedule_info,
                  :run_time => job.last})
      end
      { :result => result, :jobs => jobs }
    end

    desc "find jobs"
    get "/find_jobs" do
      content_type 'json'
      jobs = Scheduler.find_jobs_by_tag('conversion')
      { :result => result, :jobs => jobs }
    end

    desc "run test job"
    put "/test" do
      content_type 'json'
      result = Scheduler.dummyjob :start_time => params[:id].to_i,
          :from  => params[:from]  ||= Date.today.prev_day.to_s,
          :until => params[:until] ||= Date.today.to_s
      { :result => result }
    end    
    
  end # end scheduler namespace

  resource :rules do
    desc "return all rules or specific rule"
    get "/" do
      content_type 'json'
      unless params[:id]
        { :rules => Rule.new.all }
      else
        logger.info params
        rule = Rule.find(params)
        error!("No rule with id: #{params[:id]}", 404) unless rule
        { :rule => rule }        
      end        
    end  

    desc "create new rule"
      params do
        requires :name,        type: String, desc: "Short Name of Rule"
        requires :description, type: String, length: 5, desc: "Description"
        requires :script,      type: String, length: 15, desc: "The actual Rule"
        optional :tag,         type: String, desc: "Tag to recognize rule"
        optional :start_time,  desc: "Time to start rule"
        optional :frequency,   desc: "cron frequency" 
      end
    post "/" do
      content_type 'json'
      rule = Rule.new.create(params)
      rule.save
      logger.info "POST: params: #{params} - created rule: #{rule}"
      { :rule => rule }
    end
    
    desc "edit/update rule"
      params do
        requires :id,          type: String, desc: "ID of Rule"
        optional :name,        type: String, desc: "Short Name of Rule"
        optional :description, type: String, length: 5, desc: "Description"
        optional :script,      type: String, length: 15, desc: "The actual Rule"
        optional :tag,         type: String, desc: "Tag to recognize rule"
        optional :start_time,  desc: "Time to start rule"
        optional :frequency,   desc: "cron frequency" 
      end
    put "/" do
      content_type 'json'
      valid_params = ['id','name','description','script','tag','start_time','frequency']
      # do we have a valid parameter?
      if valid_params.any? {|p| params.has_key?(p) }
        rule = Rule.new.find(:id => params[:id])
        rule.update(params)
        logger.info "updated rule: #{rule}"
        { :rule => rule}
      else
        logger.error "invalid or missing params"   
        error!("Need at least one param of id|description|script|tag|start_time|frequency", 400)      
      end
    end
    
    desc "delete a rule"
      params do
        requires :id, type: String, desc: "ID of rule"
      end
    delete "/" do
      content_type 'json'
      rule = Rule.new.find(:id => params[:id])
      rule.delete
      logger.info "DELETE: params: #{params} - deleted rule: #{rule}"
      { :rule => rule }
    end        
  end # end rules namespace    
end
