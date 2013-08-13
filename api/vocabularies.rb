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
          { :vocabularies => Vocabulary.all }
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
        vocabulary.save
        logger.info "POST: params: #{params} - created vocabulary: #{vocabulary}"
        { :vocabulary => vocabulary }
      end
      
      desc "edit/update vocabulary"
        params do
          requires :prefix,        type: String, desc: "Prefix of Vocabulary"
          requires :uri,           type: String, desc: "URI of Vocabulary"
        end
      put "/" do
        content_type 'json'
        vocabulary = Vocabulary.find(:prefix => params[:prefix])
        vocabulary.update(params)
        logger.info "updated vocabulary: #{vocabulary}"
        { :vocabulary => vocabulary}
      end
      
      desc "delete a vocabulary"
      delete "/:prefix" do
        content_type 'json'
        vocabulary = Vocabulary.find(:prefix => params[:prefix])
        vocabulary.delete
        logger.info "DELETE: params: #{params} - deleted vocabulary: #{vocabulary}"
        { :vocabulary => vocabulary }
      end        
    end # end vocabularies namespace    
  end
end
