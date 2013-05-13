#encoding: utf-8
# Struct for Harvest class 

Harvest = Struct.new(:id, :name, :description, :protocol, :url, :namespaces, :params, :harvest, :limits, :client, :batch, :response, :statements)
class Harvest

  # a Harvest is a harvest job to be run, either at intervals or at specified time, against a specified record batch
  # Harvesting against external sources uses isbn from manifestation
  # Harvest should be managed by Scheduler via API calls
  
  def all
    harvests = []
    file     = File.join(File.dirname(__FILE__), '../db/', 'harvest.json')
    template = File.join(File.dirname(__FILE__), '../config/templates/', 'harvest.json')
    # first create harvest.json file from template if it doesn't exist already
    unless File.exist?(file)
      open(file, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(IO.read(template))))}
    end
    File.copy(template, file) unless File.exist?(file)
    data = JSON.parse(IO.read(file))
    data.each {|harvest| harvests << harvest.to_struct("Harvest") }
    harvests
  end
  
  def find(params)
    return nil unless params[:id]
    self.all.detect {|harvest| harvest.id == params[:id] }
  end
  
  
  # new harvest, repeated or frequent
  def create(params={})
    # populate Harvest Struct    
    self.members.each {|name| self[name] = params[name] unless params[name].nil? } 
    self.id         = SecureRandom.uuid
    self
  end
  
  def update(params)
    return nil unless self.id
    params.delete(:id)
    self.members.each {|name| self[name] = params[name] unless params[name].nil? }
    save
  end
  
  def save
    return nil unless self.id
    harvests = self.all
    match = self.find(:id => self.id)
    if match
      # overwrite harvest if match
      harvests.map! { |harvest| harvest.id == self.id ? self : harvest}
    else
      # new harvest if no match
      harvests << self
    end 
    open(File.join(File.dirname(__FILE__), '../db/', 'harvest.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(harvest.to_json))) } 
    self
  end
  
  def delete
    return nil unless self.id
    harvests = self.all
    harvests.delete_if {|lib| lib.id == self.id }
    open(File.join(File.dirname(__FILE__), '../db/', 'harvest.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(harvest.to_json))) } 
    harvests
  end
  
  def reload
    self.find(:id => self.id)
  end  
  
  
  ### Client methods
  def connect
    self.client = Net::HTTP::Persistent.new self.id
  end
  
  def disconnect
    self.client.shutdown
  end

  def validate
    self.response.code == "200"
  end
  
  ### Actual harvesting
  def harvest
    return nil unless self.batch and self.harvest
    self.statements = []
    self.isbns.each do |isbn|
      fetch_xpath_results(isbn)
      
      self.harvest.each do |predicate, opts|
        result = parse_xml(self.response, :xpath => opts['xpath'], :regexp_strip => opts['regex_strip'], :namespaces => self.namespaces)
        unless result.empty?
          case opts['datatype']
          when "uri" 
            objects.map! { |obj| RDF::URI("#{obj}") }
          else
            objects.each do | obj |
              if opts['append_to'] == 'FABIO.Work'
              ### HERE!
                self.statements << RDF::Statement.new(RDF::URI.new("#{solution.work}"), RDF.module_eval("#{predicate}"), obj)
              else
                self.statements << RDF::Statement.new(RDF::URI.new("#{solution.book}"), RDF.module_eval("#{predicate}"), obj)
              end
            end
            @count += 1
          end
        end
      end
    end #self.isbns.each
  end

  def fetch_xpath_results(isbn)
    self.response = self.client.request URI "#{self.url['prefix']}#{isbn}#{self.url['suffix']}"
  end
  
  def parse_xml(http_response, opts={})
    conditions.delete_if {|k,v| v.nil?} #delete unused conditions
    # make sure we get valid response
    if http_response.code == "200"
      xml = Nokogiri::XML(http_response.body)
      results = []
      xml.xpath("#{opts[:xpath]}", opts[:namespaces]).each { | elem | results << elem.text }
      if opts[:regexp_strip]
        results.each { |result| result.gsub!("#{opts[:regexp_strip]}", "") }
      end
      puts results
      return results
    end
  end
      

    
end
