#!/usr/bin/env ruby 
#encoding: utf-8
module API
  class Vocabularies < Grape::API
    ### vocabularies namespace ###
    resource :vocabularies do
      desc "return all vocabularies or specific vocabulary"
      get "/" do
        content_type 'json'
        unless params[:prefix]
          { :vocabularies => Vocabulary.all.sort_by {|v|v.prefix} }
        else
          logger.info params
          vocabulary = Vocabulary.find(params)
          error!("No vocabulary with prefix: #{params[:prefix]}", 404) unless vocabulary
          { :vocabulary => vocabulary }        
        end        
      end  
  
      desc "create new vocabulary"
        params do
          requires :prefix,        type: String, desc: "Prefix of Vocabulary"
          requires :uri,           type: String, desc: "URI of Vocabulary"
        end
      post "/" do
        content_type 'json'
        vocabulary = Vocabulary.new.create(params)
        result = vocabulary.save
        error!("Illegal or protected prefix", 404) unless result
        logger.info "POST: params: #{params} - created vocabulary: #{result}"
        { :vocabulary => result }
      end
      
      desc "edit/update vocabulary"
        params do
          requires :prefix,        type: String, desc: "Prefix of Vocabulary"
          requires :uri,           type: String, desc: "URI of Vocabulary"
        end
      put "/" do
        content_type 'json'
        vocabulary = Vocabulary.find(:prefix => params[:prefix])
        result = vocabulary.update(params)
        error!("Illegal or protected prefix", 404) unless result
        logger.info "updated vocabulary: #{result}"
        { :vocabulary => result}
      end
      
      desc "delete a vocabulary"
      delete "/:prefix" do
        content_type 'json'
        vocabulary = Vocabulary.find(:prefix => params[:prefix])
        error!("Vocabulary not found", 404) unless vocabulary
        result = vocabulary.delete
        logger.info "DELETE: params: #{params} - deleted vocabulary: #{result}"
        { :vocabulary => result }
      end        
    end # end vocabularies namespace    
  end
end
