#encoding: utf-8
# Struct for OAImodeler class 
require "faraday"
require "oai"
#require "libxml_ruby"

OAIClient = Struct.new(:client, :http, :oai_id, :parser, :format, :identify_response, :response, :set, :available_sets, :records)
class OAIClient
  # initialize OAI client with optional parameters. 
  # faraday connection can be overridden by passing a faraday object as :http arg
  def initialize(repo, params={}) 
    faraday = Faraday.new do | conn |
      conn.request :retry, 
                :max => 3
      conn.options[:timeout]      = params[:timeout].to_i
      conn.options[:open_timeout] = 20
    end
    self.format = params[:format] ||= 'bibliofilmarc'
    self.parser = params[:parser] ||= 'rexml'
    self.http   = params[:http]   ||= faraday
    self.client = OAI::Client.new(repo, { 
      :redirects => params[:redirects]    ||= false, 
      :debug     => params[:debug]        ||= false,
      :parser    => self.parser,
      :http      => self.http
      }
    )
    params[:set] ? self.set = params[:set] : ''
    self.records = []
  end

  # query OAI from timestamp, default yesterday 
  def query(params={})
    from_date = Time.parse(params[:from]).strftime("%F") rescue Date.today.prev_day.to_s
    to_date   = Time.parse(params[:until]).strftime("%F") rescue Date.today.to_s
    set       = params[:set]     ||= self.set
    # allow 5 retries of connection
    retries  = 5
    attempts = 0
    begin
      if params[:resumption_token]
        self.response = self.client.list_records :resumption_token => params[:resumption_token]
      else
        unless set.empty?
          self.response = self.client.list_records :metadata_prefix => self.format, :from => from_date, :until => to_date, :set => set
        else
          self.response = self.client.list_records :metadata_prefix => self.format, :from => from_date, :until => to_date
        end
      end
    rescue TimeoutError => e # Connection timed out
      puts "TimeoutError in OAI query:\n#{e}"
      if (attempts += 1) <= retries
        puts "retry...#{attempts}"
        sleep(5 * attempts)
        retry
      else
        puts "...giving up!"
        exit(1)
      end
    rescue Errno::ECONNRESET => e # Connection reset by peer 
      puts "Connection reset in OAI query:\n#{e}"
      if (attempts += 1) <= retries
        puts "retry...#{attempts}"
        sleep(5 * attempts)
        retry
      else
        puts "...giving up!"
        exit(1)
      end
    rescue Errno::ECONNREFUSED => e # Connection refused 
      puts "Connection refused in OAI query:\n#{e}"
      if (attempts += 1) <= retries
        puts "retry...#{attempts}"
        sleep(5 * attempts)
        retry
      else
        puts "...giving up!"
        exit(1)
      end
    rescue REXML::ParseException => e # xml parsing error
      puts "XML parsing error in response:\n#{e}"
      if (attempts += 1) <= retries
        puts "retry...#{attempts}"
        sleep(5 * attempts)
        retry
      else
        puts "...giving up!"
        exit(1)
      end
    rescue StandardError => e # StandardError
      puts "StandardError in OAI query:\n#{e}"
      if (attempts += 1) <= retries
        puts "retry...#{attempts}"
        sleep(5 * attempts)
        retry
      else
        puts "...giving up!"
        exit(1)
      end
    rescue Exception => e # Any other Exception
      puts "StandardError in OAI query:\n#{e}"
      if (attempts += 1) <= retries
        puts "retry...#{attempts}"
        sleep(5 * attempts)
        retry
      else
        puts "...giving up!"
        exit(1)
      end      
    end
    self.records = []
    self.response.each {|r| self.records << r }
    self.records
  end
  
  # load response from previously saved file  
  def query_from_file(file, params={})
    xml = IO.read(file).force_encoding('ASCII-8BIT')
    response = Faraday.new(:url => 'http://example.com') do |builder|
      builder.adapter :test do |stub|
        stub.get('/oai?from=1970-01-01&metadataPrefix=bibliofilmarc&until=1970-01-01&verb=ListRecords') {[200, {}, xml]}
      end
    end
    dummyoai = OAIClient.new('http://example.com/oai', :http => response, :format => 'bibliofilmarc')
    self.response = dummyoai.query :from => "1970-01-01", :until => "1970-01-01", :set => ""
    self.records = []
    self.response.each {|r| self.records << r }
    self.records
  end
    
  # query OAI for specific records
  def get_record(params={})
    identifier     = params[:identifier]      ||= 'oai:bibliofil.no:NO-2030000:14890'
    begin
      self.records = self.client.get_record :identifier => params[:identifier], :metadata_prefix => self.format
    rescue Exception => e
      puts "Error in OAI query: #{e}"
    end
  end
  
  # get library OAI identifier
  def get_oai_id
    unless self.set.empty?
      xml = self.client.list_identifiers :set => self.set
    else
      xml = self.client.list_identifiers
    end
    id = xml.first.identifier
    self.oai_id = id.rpartition(':').first
  end
  
  # get metadata formats
  def list_formats
    formats = self.client.list_metadata_formats.entries
  end
  
  # identify and validate OAI repo
  def validate
    begin
      self.identify_response = self.client.identify
      self.identify_response.is_a?(OAI::IdentifyResponse)
      get_oai_id
      get_available_sets
    rescue ArgumentError => e
      puts "#{e}" if ENV['RACK_ENV'] == "development"
      self.identify_response = nil
    end
  end

  # get sets if available
  def get_available_sets
    begin
      sets = self.client.list_sets
      self.available_sets = []
      sets.each {|set| self.available_sets << {:name => set.name, :description => set.description, :spec => set.spec} }
    rescue OAI::Exception => e
      puts e if ENV['RACK_ENV'] == "development"
      self.available_sets = nil
    end
  end
    
  # harvest all! in memory = SLOW and potentially stalling entire app!
  def query_all
    set  = params[:set]     ||= self.set
    self.client.list_records.full :metadata_prefix => self.format, :set => set
  end
  
  # count records in set (slow!)
  def query_count_all
    self.client.list_identifiers.full.count
  end
  
end
