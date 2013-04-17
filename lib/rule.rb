#encoding: utf-8
# Struct for Rule class 

Rule = Struct.new(:id, :type, :job_id, :cron_id, :tag, :name, :description, :start_time, :frequency, :script, :last_result)
class Rule

  # a Rule is a SPARQL script to be run, either at intervals or at specified time
  # Rules are either global or connected to a Library
  # Rules are managed by Scheduler via API calls
  
  def all
    rules = []
    file     = File.join(File.dirname(__FILE__), '../db/', 'rules.json')
    template = File.join(File.dirname(__FILE__), '../config/templates/', 'rules.json')
    # first create library file from template if it doesn't exist already
    unless File.exist?(file)
      open(file, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(IO.read(template))))}
    end
    File.copy(template, file) unless File.exist?(file)
    data = JSON.parse(IO.read(file))
    data.each {|rule| rules << rule.to_struct("Rule") }
    rules
  end
  
  def find(params)
    return nil unless params[:id]
    self.all.detect {|rule| rule.id == params[:id] }
  end
  
  def find_by_tag()
  end
  
  # new rule, repeated or frequent
  def create(params={})
    # populate Rule Struct    
    self.members.each {|name| self[name] = params[name] unless params[name].nil? } 
    self.id         = SecureRandom.uuid
    self.start_time = params[:start_time]
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
    rules = self.all
    match = self.find(:id => self.id)
    #sanitize # clean script before saving
    if match
      # overwrite rule if match
      rules.map! { |rule| rule.id == self.id ? self : rule}
    else
      # new rule if no match
      rules << self
    end 
    open(File.join(File.dirname(__FILE__), '../db/', 'rules.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(rules.to_json))) } 
    self
  end
  
  def delete
    return nil unless self.id
    rules = self.all
    rules.delete_if {|lib| lib.id == self.id }
    open(File.join(File.dirname(__FILE__), '../db/', 'rules.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(rules.to_json))) } 
    rules
  end
  
  def reload
    self.find(:id => self.id)
  end  
  
  def localize(library)
    return nil unless self.id and self.script
    self.script.gsub!(/DEFAULT_GRAPH/, RDF::URI(library.config['resource']['default_graph']).to_ntriples)
    self.script.gsub!(/DEFAULT_PREFIX\.([^\s]+)/, '<' +library.config['resource']['default_prefix'] + '\1>')
    self
  end
  
  def globalize
    return nil unless self.id and self.script
    self.script.gsub!(/DEFAULT_GRAPH/, RDF::URI(SETTINGS['global']['default_graph']).to_ntriples)
    self.script.gsub!(/DEFAULT_PREFIX\.([^\s]+)/, '<' +SETTINGS['global']['default_prefix'] + '\1>')
    self
  end
  
  def sanitize
    # need to remove apostrophes before saving script
    return nil unless self.id and self.script
    self.script.gsub!('"', "'")
    self.script.gsub!(/(?=[`])/, '\\')
    self
  end
end
