#encoding: utf-8
# Struct for OAImodeler class 
require "faraday"
require "oai"
#require "libxml_ruby"

OAIClient = Struct.new(:client, :http, :oai_id, :parser, :format, :identify_response, :response, :datasets, :records)
class OAIClient
  # initialize OAI client with optional parameters. 
  # faraday connection can be overridden by passing a faraday object as :http arg
  def initialize(repo, params={}) 
    faraday = Faraday.new :request => {:open_timeout => 20, :timeout => params[:timeout].to_i }
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
    self.records = []
  end

  # query OAI from timestamp, default yesterday 
  def query(params={})
    from_date = params[:from]  ||= Date.today.prev_day.to_s
    to_date   = params[:until] ||= Date.today.to_s
    if params[:resumption_token]
      self.response = self.client.list_records :resumption_token => params[:resumption_token]
    else
      self.response = self.client.list_records :metadata_prefix => self.format, :from => from_date, :until => to_date
    end
    self.response.each {|r| self.records << r }
    self.records
  end
    
  # query OAI for specific records
  def get_record(params={})
    identifier     = params[:identifier]      ||= 'oai:bibliofil.no:NO-2030000:14890'
    self.records = self.client.get_record :identifier => params[:identifier], :metadata_prefix => self.format
  end
  
  # get library OAI identifier
  def get_oai_id
    xml = self.client.list_identifiers
    id = xml.first.identifier
    self.oai_id = id.rpartition(':').first
  end
  
  # get sets if available
  def get_sets
    begin
      self.datasets = self.client.list_sets
    rescue OAI::Exception => e
      puts e if ENV['RACK_ENV'] == "development"
      self.datasets = nil
    end
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
      get_sets
    rescue ArgumentError => e
      puts e if ENV['RACK_ENV'] == "development"
      self.identify_response = nil
    end
  end
  
  # harvest all! in memory = SLOW and potentially stalling entire app!
  def query_all
    self.records = self.client.list_records.full
  end
  
  # count records in set (slow!)
  def query_count_all
    self.client.list_identifiers.full.count
  end
  
end
