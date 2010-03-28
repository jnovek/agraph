require File.join(File.dirname(__FILE__), "server")
require File.join(File.dirname(__FILE__), "session")
require File.join(File.dirname(__FILE__), "proxy", "statements")
require File.join(File.dirname(__FILE__), "proxy", "query")
require File.join(File.dirname(__FILE__), "proxy", "geo")

module AllegroGraph

  class Repository

    attr_reader   :server
    attr_reader   :catalog
    attr_accessor :name

    attr_reader   :statements
    attr_reader   :query
    attr_reader   :geo

    def initialize(server_or_catalog, name, options = { })
      @catalog    = server_or_catalog.is_a?(AllegroGraph::Server) ? server_or_catalog.root_catalog : server_or_catalog
      @server     = @catalog.server
      @name       = name
      @statements = Proxy::Statements.new self
      @query      = Proxy::Query.new self
      @geo        = Proxy::Geo.new self
    end

    def ==(other)
      other.is_a?(self.class) && self.catalog == other.catalog && self.name == other.name
    end

    def path
      "#{@catalog.path}/repositories/#{@name}"
    end

    def request(http_method, path, options = { })
      @server.request http_method, path, options
    end

    def exists?
      @catalog.repositories.include? self
    end

    def create!
      @server.request :put, self.path, :expected_status_code => 204
      true
    rescue ExtendedTransport::UnexpectedStatusCodeError => error
      return false if error.status_code == 400
      raise error
    end

    def create_if_missing!
      create! unless exists?
    end

    def delete!
      @server.request :delete, self.path, :expected_status_code => 200
      true
    rescue ExtendedTransport::UnexpectedStatusCodeError => error
      return false if error.status_code == 400
      raise error
    end

    def delete_if_exists!
      delete! if exists?
    end

    def size
      response = @server.request :get, self.path + "/size", :type => :text, :expected_status_code => 200
      response.to_i
    end

    def transaction(&block)
      session = Session.create self
      begin
        session.instance_eval &block
      rescue Object => error
        session.rollback
        raise error
      end
      session.commit
    end

  end

end
