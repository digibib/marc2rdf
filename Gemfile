source "https://rubygems.org"
gem "builder"
gem "bundler", "~> 1.3.5"
gem "nokogiri"
gem "net-http-persistent", :require => 'net/http/persistent'
gem "marc"
gem "rdf"
gem "rdf-rdfxml", :require => 'rdf/rdfxml'
gem "rdf-n3", :require => 'rdf/n3'
gem "rdf-virtuoso", :require => 'rdf/virtuoso'
#gem "oai", :git => 'https://github.com/code4lib/ruby-oai.git'
gem "oai"
gem "libxml-ruby" # seems broken!! test before using. (faster OAI processing)
gem "rest-client"
gem "rake"
gem "grape"#, "0.2.4" # json parameter parse broken after 0.2.4
gem "sinatra"
gem "sinatra-contrib", :require => 'sinatra/contrib'
gem "rufus-scheduler", :require => 'rufus/scheduler'
gem "slim"
gem "tilt"
gem "thin"
gem "foreman"
gem "json"
gem "ci_reporter"

group :development, :test do
  gem "sinatra-reloader"
  gem "pry"
  gem "shotgun"
end

group :test do
  gem "rspec"
  gem "rdf-spec"
  gem "rack-test"
  gem "webmock"
  gem "minitest"
end
