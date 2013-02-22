#encoding: utf-8
# Struct for OAImodeler class 
require "faraday"
require "oai"
require "libxml_ruby"

OAIClient = Struct.new(:client, :http, :oai_id, :parser, :format, :identify_response, :response, :datasets, :records)
class OAIClient
  # initialize OAI client with optional parameters. 
  # faraday connection can be overridden by passing a faraday object as :http arg
  def initialize(repo, args={}) 
    faraday = Faraday.new :request => {:open_timeout => 20, :timeout => args[:timeout].to_i }
    self.format = args[:format] ||= 'bibliofilmarc'
    self.parser = args[:parser] ||= 'libxml'
    self.http   = args[:http]   ||= faraday
    self.client = OAI::Client.new(repo, { 
      :redirects => args[:redirects]    ||= false, 
      :debug     => args[:debug]        ||= false,
      :parser    => self.parser,
      :http      => self.http
      }
    )
  end

  # query OAI
  def query(args={})
    from_date = args[:from]  ||= Date.today.prev_day.to_s
    to_date   = args[:until] ||= Date.today.to_s
    self.response  = self.client.list_records :metadata_prefix => self.format, :from => from_date, :until => to_date
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
    rescue ArgumentError => e
      puts e if ENV['RACK_ENV'] == "development"
      self.identify_response = nil
    end
  end
  
  # harvest all! = SLOW!
  def get_all
    self.records = self.client.list_records.full
  end
end
