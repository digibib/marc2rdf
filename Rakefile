require 'rspec/core/rake_task'
require 'ci/reporter/rake/rspec'

$stdout.sync = true # gives foreman full stdout
task :default => :help

desc "Show help menu"
task :help do
  puts "Available rake tasks: "
  puts "rake console - Run a IRB console with all enviroment loaded"
  puts "rake spec - Run specs and calculate coverage"
end

desc "Run specs"
task :spec do
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = './spec/**/*_spec.rb'
  end
end

desc "Run CI rspec"
task "ci_rspec" => ["ci:setup:rspec", "^spec"]

desc "Run IRB console with app environment"
task :console do
  puts "Loading development console..."
  system("irb -r ./api.rb")
end

desc "Starts the Scheduler worker"
task :scheduler do
  require File.join(File.dirname(__FILE__), 'lib', 'rules.rb')
  scheduler.join
end

desc "activates all saved schedules and scheduled rules if Scheduler is restarted and in production mode"
task :load_activated_schedules do
  require File.join(File.dirname(__FILE__), 'config', 'init.rb')
  
  t = Thread.new do 
    puts "waiting 5 sec before activating schedules..."
    sleep(5)
    Scheduler = DRbObject.new_with_uri DRBSERVER
    begin
      ### activate library OAI schedules ###
      Library.all.each do |library|
        next unless library.oai["schedule"]
        unless library.oai["schedule"].empty?
          Scheduler.schedule_oai_harvest(:id => library.id) 
          puts "Activating OAI scheduled harvest: #{library.name}"
        end
      end
    rescue Exception => e
      puts "error #{e}"
    end
    begin
      ### activate scheduled global Rules ###
      Rule.all.each do |rule|
        if not rule.frequency.empty? and rule.type == "global"
          rule.globalize
          rule.sanitize
          puts "Activating scheduled rule: #{rule.name}"
          Scheduler.schedule_isql_rule(rule) 
        end
      end
    rescue Exception => e
      puts "error #{e}"
    end
    puts "...done"
    sleep()
  end
  t.join
end


