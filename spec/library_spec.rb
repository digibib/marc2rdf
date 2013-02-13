#!/usr/bin/env ruby
# encoding: UTF-8
require "spec_helper"

describe Library do
  context 'find' do
    
    it "saves a new library" do
      params = {:name => "Spec Test Library"}
      l = Library.new.create(params)
      l.save
      l.id.should >= 1
      l.name.to_s.should == "Spec Test Library"
    end
    
    it "returns all libraries" do
      l = Library.new.all
      l.count.should >= 1
    end
    
    it "returns a library by id" do
      params = {:id => 1}
      l = Library.new.find(params)
      l.name.to_s.should == "Test Library"
    end
    
    it "returns a library by name" do
      params = {:name => "Spec Test Library"}
      l = Library.new.find(params)
      l.name.to_s.should == "Spec Test Library"
    end
  end
  context 'update' do
    it "updates library" do
      params = {:name => "Spec Test Library"}
      l = Library.new.find(params)
      params = {:name => "Spec Test Library 2", :config => {:dummy => "value"}}
      l.update(params)
      l.name.to_s.should == "Spec Test Library 2"
      l.config[:dummy].should == "value"
    end
    it "deletes a library" do
      params = {:name => "Spec Test Library 2"}
      l = Library.new.find(params)
      l.delete
      Library.new.find(params).should == nil
    end
  end
end
