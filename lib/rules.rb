#encoding: utf-8
# Struct for Rule class 
require 'rufus/scheduler'

Rule = Struct.new(:id, :scheduler, :job, :cronjob, :tag, :name, :description, :start_time, :frequency, :script)
class Rule

  # a Rule is a SPARQL script to be run, either at intervals or at specified time
  
  # start a Rufus::Scheduler object if not already done
  def initialize(scheduler=nil)
    self.scheduler = scheduler ||= Rufus::Scheduler.start_new(:frequency => 10.0)
  end
  
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
    data.each {|rule| rules << rule.to_struct("Rules") }
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
    self.start_time = params[:start_time] ||= DateTime.now
    self
  end
  
  def update(params)
    return nil unless self.id
    params.delete(:id)
    self.members.each {|name| self[name] = params[name] unless params[name].nil? }
  end
  
  def save
    return nil unless self.id
    rules = self.all
    match = self.find(:id => self.id)
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
  
  #private
  # routines to start/pause/stop and lookup Rufus::Scheduler rules
  def activate
    self.job = self.scheduler.at "#{self.start_time}", :tags => self.tag do 
      puts self.script if self.script # run script here
    end
  end
  
  # make job into schedule
  def schedule
    self.cronjob = self.scheduler.cron "#{self.frequency}", :tags => self.tag do 
      puts self.script if self.script # run script here
    end
  end
  
  def pause
    self.job.pause
  end

  def resume
    self.job.resume
  end
    
  def unschedule
    self.cronjob.unschedule
  end
  
  # returns a map job_id => job of at/in/every jobs  
  def find_jobs
    self.scheduler.jobs
  end

  def find_cronjobs
    self.scheduler.cron_jobs
  end
  
  def find_all_jobs
    self.scheduler.all_jobs
  end

  def find_jobs_by_tag(t)
    self.scheduler.find_by_tag(t)
  end
  
end
