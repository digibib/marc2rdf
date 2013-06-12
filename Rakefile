require 'rspec/core/rake_task'

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

desc "Run IRB console with app environment"
task :console do
  puts "Loading development console..."
  system("irb -r ./config/boot.rb")
end

desc "Starts the Scheduler worker"
task :scheduler do
  require './lib/rules.rb'
  scheduler.join
end

desc "activates all saved schedules if Scheduler is restarted and in production mode"
task :load_activated_schedules do
  require_relative "./config/init.rb"
  
  t = Thread.new do 
    sleep(5)
    begin
      Scheduler = DRbObject.new_with_uri DRBSERVER
      Library.all.each do |library|
        Scheduler.schedule_oai_harvest(:id => library.id) unless library.oai["schedule"].empty?
      end
    rescue Exception => e
      puts "error #{e}: must be activated after app is running"
      
    end
    sleep()
  end
  t.join
end


