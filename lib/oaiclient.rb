#encoding: utf-8
# Struct for OAImodeler class 
require "faraday"
require "oai"

OAIClient = Struct.new(:client, :format, :identify, :response, :records)
class OAIClient
  def initialize(repo=nil, args={:timeout => 60, :redirects => false, :parser => 'rexml', :format => 'bibliofilmarc'}) 
    faraday = Faraday.new :request => {:open_timeout => 20, :timeout => args[:timeout] }
    self.client = OAI::Client.new(repo, {:redirects => args[:redirects], :parser => args[:parser], :timeout => args[:timeout], :debug => args[:debug], :http => faraday})
    self.format = args[:format]
  end

  def query(from_date=Date.today.prev_day.to_s, until_date=Date.today.to_s)
    response = self.client.list_records :metadata_prefix => self.format, :from => from_date, :until => until_date
  end  

  def identify
    self.identify = client.identify
  end
  
  # harvest all!
  def get_all
    self.records = self.client.list_records.full
  end
end
