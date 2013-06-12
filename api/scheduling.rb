#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Scheduling < Grape::API
  resource :scheduler do
    ### Find jobs ###
    desc "all jobs"
    get "/" do
      content_type 'json'
      jobs = Scheduler.find_all_jobs
      { :jobs => jobs }
    end
    
    # list running jobs
    desc "running jobs"
    get "/running_jobs" do
      content_type 'json'
      result = Scheduler.find_running_jobs
      jobs = []
      result.each do |job|
        jobs.push({:job_id    => job.job_id,
                  :scheduler => job.scheduler,
                  :start_time => job.t,
                  :last_job_thread => job.last_job_thread,
                  :params => job.params,
                  :block => job.block,
                  :schedule_info => job.schedule_info,
                  :run_time => job.last})
      end
      { :result => result, :jobs => jobs }
    end

    desc "find scheduled jobs"
    get "/find_scheduled_jobs" do
      content_type 'json'
      result = Scheduler.find_scheduled_jobs
      jobs = []
      result.each do |job|
        jobs.push({:job_id    => job.job_id,
                  :scheduler => job.scheduler,
                  :start_time => job.t,
                  :last_job_thread => job.last_job_thread,
                  :params => job.params,
                  :block => job.block,
                  :schedule_info => job.schedule_info,
                  :run_time => job.last})
      end
      { :result => result, :jobs => jobs }
    end

    desc "find all jobs"
    get "/find_all_jobs" do
      content_type 'json'
      result = Scheduler.find_all_jobs
      jobs = []
      result.each do |name, job|
        jobs.push({:job_id    => job.job_id,
                  :scheduler => job.scheduler,
                  :start_time => job.t,
                  :last_job_thread => job.last_job_thread,
                  :params => job.params,
                  :block => job.block,
                  :schedule_info => job.schedule_info,
                  :run_time => job.last})
      end
      { :result => result, :jobs => jobs }
    end
        
    desc "find jobs by tag"
    get "/find_jobs_by_tag" do
      content_type 'json'
      jobs = Scheduler.find_jobs_by_tag('conversion')
      { :result => result, :jobs => jobs }
    end

    ### Run/Schedule Rules ###
    
    desc "run test job"
    put "/test" do
      content_type 'json'
      result = Scheduler.dummyjob :start_time => params[:id],
          :from  => params[:from]  ||= Date.today.prev_day.to_s,
          :until => params[:until] ||= Date.today.to_s
      { :result => result }
    end
    
    desc "Start Rule as one-time job"
      params do
        requires :id,          type: String, desc: "ID of Rule"
        optional :start_time,  desc: "Time to start rule"
        optional :library,     type: Integer, desc: "Library ID to run rule against"
      end
    put "/run_rule" do
      content_type 'json'
      rule = Rule.find(:id => params[:id])
      error!("No rule with id: #{params[:id]}", 404) unless rule
      # Make sure to localize if library param sent
      if params[:library]
        library = Library.find(:id => params[:library].to_i) 
        error!("No library with id: #{params[:library]}", 404) unless library
        rule.localize(library)
        rule.library = library.id
      else
        rule.globalize
      end
      rule.sanitize
      # start time by either: 1) param, 2) rule's start_time or 3) now 
      rule.start_time = params[:start_time] ? params[:start_time] :
        rule.start_time.empty? ? Time.now : rule.start_time
      result = Scheduler.run_isql_rule(rule)
      { :result => result }
    end    

    # Schedule Rule: only used on Global Rules, local rules are run as part of OAI update cycle
    desc "Activate Rule as schedule"
      params do
        requires :id,        type: String, desc: "ID of Rule"
        optional :frequency, type: String, desc: "Frequency of rule"
        optional :library,   type: Integer, desc: "Library ID to run rule against"
      end
    put "/schedule_rule" do
      content_type 'json'
      rule = Rule.find(:id => params[:id])
      error!("No rule with id: #{params[:id]}", 404) unless rule
      # allow override frequency with param 
      rule.frequency = params[:frequency] ? params[:frequency] : rule.frequency
      error!("Missing or invalid frequency!", 404) if rule.frequency.empty?
      # Make sure to localize if library param sent
      if params[:library]
        library = Library.find(:id => params[:library].to_i) 
        error!("No library with id: #{params[:library]}", 404) unless library
        rule.localize(library)
        rule.library = library.id
      else
        rule.globalize
      end
      rule.sanitize
      result = Scheduler.schedule_isql_rule(rule)
      { :result => result }
    end
    
    desc "Activate Local Rule"
      params do
        requires :id,        type: String, desc: "ID of Harvester"
        requires :library,   type: Integer, desc: "Library ID to run Harvester against"
      end
    put "/activate_rule" do
      content_type 'json'
      rule    = Rule.find(:id => params[:id])
      error!("No rule with id: #{params[:id]}", 404) unless rule
      library = Library.find(:id => params[:library].to_i) 
      library.rules.push({:id => rule.id}) unless library.rules.any? {|lr| lr['id'] == rule.id}
      library.update
      { :library => library }
    end

    desc "Deactivate Local Rule"
      params do
        requires :id,        type: String, desc: "ID of Harvester"
        requires :library,   type: Integer, desc: "Library ID to run Harvester against"
      end
    put "/deactivate_rule" do
      content_type 'json'
      rule = Rule.find(:id => params[:id])
      error!("No rule with id: #{params[:id]}", 404) unless rule
      library = Library.find(:id => params[:library].to_i) 
      library.rules.delete_if {|lr| lr['id'] == rule.id}
      library.update
      { :library => library }
    end
    
    ### Unschedule/stop ###
    desc "Stop/kill running job"
      params do
        requires :id,      type: String, desc: "ID of Job"
        optional :library, type: Integer, desc: "Library ID to run rule against"
      end
    put "/stop" do
      content_type 'json'
      #rule = Rule.find(:id => params[:id])
      begin
        job = Scheduler.find_running_jobs.select {|j| j.job_id == params[:id] }
      rescue ArgumentError => e
        error!("Error: #{e}, job with id: #{params[:id]} not found", 404)
      end
      #if params[:library]
      #  # make sure to delete rule from library.rules array
      #  library = Library.find(:id => params[:library].to_i) 
      #  error!("No library with id: #{params[:library]}", 404) unless library
      #  library.rules.delete_if {|r| r['id'] == rule.id }
      #  library.update(:rules => library.rules)
      #end
      #result = Scheduler.unschedule(job)
      result = job.first.last_job_thread.kill
      { :result => result }
    end
    
    desc "Unschedule scheduled job"
      params do
        requires :id,      type: String, desc: "ID of Job"
        optional :library, type: Integer, desc: "Library ID to run rule against"
      end
    put "/unschedule" do
      content_type 'json'
      begin
        job = Scheduler.scheduler.find(params[:id])
      rescue ArgumentError => e
        error!("Error: #{e}, job with id: #{params[:id]} not found", 404)
      end
      result = job.unschedule
      { :result => result }
    end    

    desc "Reload scheduled job"
      params do
        requires :id,      type: String, desc: "ID of Job"
        requires :library, type: Integer, desc: "Library ID to run rule against"
      end
    put "/reload" do
      content_type 'json'
      begin
        job = Scheduler.scheduler.find(params[:id])
      rescue ArgumentError => e
        error!("Error: #{e}, job with id: #{params[:id]} not found", 404)
      end
      job.unschedule
      result = Scheduler.schedule_oai_harvest(:id => params[:library].to_i)
      { :result => result }
    end 
        
    ### Harvester ### 
    
    desc "Activate Harvester Rule"
      params do
        requires :id,        type: String, desc: "ID of Harvester"
        requires :library,   type: Integer, desc: "Library ID to run Harvester against"
      end
    put "/activate_harvester" do
      content_type 'json'
      harvester    = Harvest.find(:id => params[:id])
      error!("No harvest rule with id: #{params[:id]}", 404) unless harvester
      library = Library.find(:id => params[:library].to_i) 
      library.harvesters.push({:id => harvester.id}) unless library.harvesters.any? {|lh| lh['id'] == harvester.id}
      library.update
      { :library => library }
    end

    desc "Deactivate Harvester Rule"
      params do
        requires :id,        type: String, desc: "ID of Harvester"
        requires :library,   type: Integer, desc: "Library ID to run Harvester against"
      end
    put "/deactivate_harvester" do
      content_type 'json'
      harvester    = Harvest.find(:id => params[:id])
      error!("No harvest rule with id: #{params[:id]}", 404) unless harvester
      library = Library.find(:id => params[:library].to_i) 
      library.harvesters.delete_if {|lh| lh['id'] == harvester.id}
      library.update
      { :library => library }
    end
                
    ### History ###
    desc "get scheduler history"
    get "/history" do
      content_type 'json'
      log = Scheduler.read_history
      { :history => log["history"] }
    end
  end # end scheduler namespace
end
end
