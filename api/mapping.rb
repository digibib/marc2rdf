#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Mapping < Grape::API
  resource :mapping do
    desc "return mapping template or id"
    get "/" do
      content_type 'json'
      mapping = JSON.parse(IO.read(File.join(File.dirname(__FILE__), '../config/templates', 'mapping_skeleton.json')))
      { :mapping => mapping }
    end
  end # end mapping namespace
end
end
