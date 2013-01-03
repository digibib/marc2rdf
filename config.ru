require File.expand_path(File.dirname(__FILE__) + "/app")
require File.expand_path(File.dirname(__FILE__) + "/api")

run Rack::Cascade.new( [APP, API] )
