#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Scheduler < Grape::API
  resource :scheduler do
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

    desc "find jobs"
    get "/find_jobs" do
      content_type 'json'
      jobs = Scheduler.find_jobs_by_tag('conversion')
      { :result => result, :jobs => jobs }
    end

    desc "run test job"
    put "/test" do
      content_type 'json'
      result = Scheduler.dummyjob :start_time => params[:id].to_i,
          :from  => params[:from]  ||= Date.today.prev_day.to_s,
          :until => params[:until] ||= Date.today.to_s
      { :result => result }
    end    
    
  end # end scheduler namespace
end
end
