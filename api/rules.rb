#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Rules < Grape::API
  ### rules namespace ###
  resource :rules do
    desc "return all rules or specific rule"
    get "/" do
      content_type 'json'
      unless params[:id]
        { :rules => Rule.new.all }
      else
        logger.info params
        rule = Rule.new.find(params)
        error!("No rule with id: #{params[:id]}", 404) unless rule
        { :rule => rule }        
      end        
    end  

    desc "create new rule"
      params do
        requires :name,        type: String, desc: "Short Name of Rule"
        requires :description, type: String, length: 5, desc: "Description"
        requires :script,      type: String, length: 15, desc: "The actual Rule"
        optional :tag,         type: String, desc: "Tag to recognize rule"
        optional :start_time,  desc: "Time to start rule"
        optional :frequency,   desc: "cron frequency" 
      end
    post "/" do
      content_type 'json'
      rule = Rule.new.create(params)
      rule.save
      logger.info "POST: params: #{params} - created rule: #{rule}"
      { :rule => rule }
    end
    
    desc "edit/update rule"
      params do
        requires :id,          type: String, desc: "ID of Rule"
        optional :name,        type: String, desc: "Short Name of Rule"
        optional :description, type: String, length: 5, desc: "Description"
        optional :script,      type: String, length: 15, desc: "The actual Rule"
        optional :tag,         type: String, desc: "Tag to recognize rule"
        optional :start_time,  desc: "Time to start rule"
        optional :frequency,   desc: "cron frequency" 
      end
    put "/" do
      content_type 'json'
      valid_params = ['id','name','description','script','tag','start_time','frequency']
      # do we have a valid parameter?
      if valid_params.any? {|p| params.has_key?(p) }
        rule = Rule.new.find(:id => params[:id])
        rule.update(params)
        logger.info "updated rule: #{rule}"
        { :rule => rule}
      else
        logger.error "invalid or missing params"   
        error!("Need at least one param of id|description|script|tag|start_time|frequency", 400)      
      end
    end
    
    desc "delete a rule"
      params do
        requires :id, type: String, desc: "ID of rule"
      end
    delete "/" do
      content_type 'json'
      rule = Rule.new.find(:id => params[:id])
      rule.delete
      logger.info "DELETE: params: #{params} - deleted rule: #{rule}"
      { :rule => rule }
    end        
  end # end rules namespace    
end
end
