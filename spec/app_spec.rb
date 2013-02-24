require 'spec_helper'

describe APP do
  
  def app
    @app ||= APP
  end

  describe "GET '/'" do
    it "should be successful" do
      get '/'
      puts last_response.body
      last_response.should be_ok
    end
  end
end
