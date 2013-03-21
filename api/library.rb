# custom option validator :length
class Length < Grape::Validations::SingleOptionValidator
  def validate_param!(attr_name, params)
    unless params[attr_name].length >= @option
      throw :error, :status => 400, :message => "#{attr_name}: must be at least #{@option} characters long"
    end
  end
end

module API
  class Library < Grape::API
    # /api/library
    resource :library do
      desc "returns all libraries or specific library"
      get "/" do
        content_type 'json'
        unless params[:id]
          { :libraries => Library.new.all }
        else
          logger.info params
          library = Library.new.find(params)
          error!("No library with id: #{params[:id]}", 404) unless library
          { :library => library }        
        end
      end
      
      ### Mapping ###
       
      desc "get specific library mapping"
      get "/:id/mapping" do
        content_type 'json'
        library = Library.new.find(:id=> params[:id].to_i)
        if library
          { :mapping => library.mapping }
        else
          logger.error "library mapping not found"   
          error!("library mapping not found", 400)
        end
      end
      
      desc "create new library"
        params do
          requires :name,       type: String, length: 5, desc: "Name of library"
          optional :config,     desc: "Config file"
          optional :mapping,    desc: "Mapping file"
          optional :oai,        desc: "OAI settings"
          optional :harvesting, desc: "Harvesting settings file" 
        end
      post "/" do
        content_type 'json'
        library = Library.new.create(params)
        library.save
        logger.info "POST: params: #{params} - created library: #{library}"
        { :library => library }
      end
      
      desc "save specific library mapping"
        params do
          requires :mapping, desc: "Mapping file"
        end
      put "/:id/mapping" do
        content_type 'json'
        logger.info "PUT: mapping: #{params[:mapping]}"
        library = Library.new.find(:id => params[:id].to_i)
        puts params
        library.update(:mapping => params[:mapping])
        logger.info "PUT: params: #{params} - updated mapping: #{library.mapping}"
        { :mapping => library.mapping }
      end
              
      ### Conversion ###
      desc "convert records"
      get "/:id/convert" do
        content_type 'json'
        library = Library.new.find(:id => params[:id])
        { :record => record }
      end
    
      desc "edit/update library"
        params do
          requires :id,         type: Integer, desc: "ID of library"
          optional :name,       type: String,  length: 5, desc: "Name of library"
          optional :config,     desc: "Config file"
          optional :mapping,    desc: "Mapping file"
          optional :oai,        desc: "OAI settings"
          optional :harvesting, desc: "Harvesting settings file" 
        end
      put "/" do
        content_type 'json'
        valid_params = ['id','name','config','mapping','oai','harvesting']
        # do we have a valid parameter?
        if valid_params.any? {|p| params.has_key?(p) }
          library = Library.new.find(:id => params[:id])
          library.update(params)
          logger.info "updated library: #{library}"
          { :library => library}
        else
          logger.error "invalid or missing params"   
          error!("Need at least one param of id|name|config|mapping|oai|harvesting", 400)      
        end
      end
      
      desc "delete a library"
        params do
          requires :id, type: Integer, desc: "ID of library"
        end
      delete "/" do
        content_type 'json'
        library = Library.new.find(:id => params[:id])
        library.delete
        logger.info "DELETE: params: #{params} - deleted library: #{library}"
        { :library => library }
      end
    end # end library namespace
  end
end  
