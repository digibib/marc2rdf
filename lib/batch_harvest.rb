#encoding: utf-8
# Struct for BatchHarvest class 

BatchHarvest   = Struct.new(:harvester, :params, :client, :count, :solutions, :response, :statements)

class BatchHarvest
  # A Batch accepts an RDF::Query::Solutions as input or from a query against RDF store
  # Make sure that RDF::Query::Solutions includes :object binding, as this is used for harvesting
  
  def initialize(harvester, batch = nil)
    self.harvester   = harvester
    self.solutions = batch if batch.is_a?(RDF::Query::Solutions) # set solutions if harvest from batch
  end

  ### Client methods, make persistent connection
  def connect
    self.client = Net::HTTP::Persistent.new self.harvester.id
  end
  
  def disconnect
    self.client.shutdown
  end

  def validate_response
    self.response.code == "200"
  end
  
  ### RDFstore methods
  # Count all? Not needed?
  def count_resource(type, params={})
    graph = params[:graph] ||= SETTINGS["global"]["default_graph"]
    query = QUERY.select.where([:s, RDF.type, type]).distinct
    query.count(:s)
    query.from(RDF::URI(graph))
    solutions  = REPO.select(query)
    self.count = solutions.first[:s].to_i
  end
  
  # Main method for harvesting, iterates self.solutions if present or iterates lookup against RDF store
  def start_harvest(params={})
    params[:offset]      ||= 0
    params[:max_limit]   ||= self.harvester.limits["max_limit"]
    params[:batch_limit] ||= self.harvester.limits["batch_limit"]
    params[:retry_limit] ||= self.harvester.limits["retry_limit"]
    params[:delay]       ||= self.harvester.limits["delay"]
    self.connect
    if self.solutions
      # iterate batch until end of solutions
      while params[:offset] <= self.solutions.length
        solutions = Marshal.load(Marshal.dump(self.solutions)).offset(params[:offset]).limit(params[:batch_limit])
        run_harvester(solutions)
        params[:offset] += params[:batch_limit]
      end
    else
      # do rdf lookups and iterate until end
      while params[:offset] <= params[:max_limit]
        solutions = rdfstore_query(params)
        run_harvester(solutions)
        params[:offset] += params[:batch_limit]
      end
    end
    self.disconnect
  end
  
  # SPARQL lookup in RDF store, BIBO.isbn is default
  def rdfstore_query(params={})
    # takes params minuses|limit|offset|predicate
    params[:limit]     ||= 10
    params[:type]      ||= "RDF::BIBO.Document"
    params[:predicate] ||= "RDF::BIBO.isbn"
    params[:graph]     ||= SETTINGS["global"]["default_graph"]
    minus = params[:minuses].map { |m| [:edition, RDF.module_eval("#{m}"), :object] } if params[:minuses]

    query = QUERY.select(:work, :edition, :object)
    query.from(RDF::URI(params[:graph]))
    query.where(
      [:edition, RDF.type, RDF.module_eval("#{params[:type]}")],
      [:edition, RDF.module_eval("#{params[:predicate]}"), :object],
      [:work, RDF::FABIO.hasManifestation, :edition])
      minus.each {|m| query.minus(m) } if minus
    query.offset(params[:offset]) if params[:offset]
    query.limit(params[:limit])
    puts query
    solutions = REPO.select(query)
    return nil if solutions.empty?
    solutions
  end
  
  ### Harvesting methods
  def run_harvester(solutions)
    # need to have solutions first
    return nil unless solutions and self.harvester
    self.statements = []
    solutions.each do |solution|
      next unless solution.object # ignore if no object variable in solution
      url = "#{self.harvester.url["prefix"]}#{solution.object}#{self.harvester.url["suffix"]}"
      fetch_xpath_results(url)
      next unless self.response
      
      self.harvester.predicates.each do |predicate, opts|
        results = parse_xml(self.response, :xpath => opts["xpath"], :regexp_strip => opts["regex_strip"], :namespaces => self.harvester.namespaces)
        unless results.empty?
          case opts["datatype"]
          when "uri" 
            results.map! { |obj| RDF::URI("#{obj}") }
          else
            results.each do | obj |
              # for now objects are only added to either 'work' or 'edition' subjects
              if self.harvester.subject == 'work'
                self.statements << RDF::Statement.new(RDF::URI.new("#{solution.work}"), RDF.module_eval("#{predicate}"), obj)
              else
                self.statements << RDF::Statement.new(RDF::URI.new("#{solution.edition}"), RDF.module_eval("#{predicate}"), obj)
              end
            end
          end
        end
      end
    end #self.isbns.each
  end

  def fetch_xpath_results(url)
    self.response = self.client.request URI.parse url
  end
  
  def parse_xml(http_response, opts={})
    opts.delete_if {|k,v| v.nil?} #delete unused conditions
    # make sure we get valid response
    if http_response.code == "200" || http_response.code == "302" 
      xml = Nokogiri::XML(http_response.body)
      #results = []
      #xml.xpath("#{opts[:xpath]}", opts[:namespaces]).each { | elem | results << elem.text }
      results = xml.xpath("#{opts[:xpath]}", xml.namespaces.merge(opts[:namespaces]))
      # optional regex strip
      return nil unless results
      results.each { |result| result.gsub!("#{opts[:regexp_strip]}", "") } if opts[:regexp_strip]
      return results
    end
  end

end