require "nori"

module Sinatra
  module Soap
    class Request

      attr_reader :wsdl, :action, :env, :request, :params, :response

      alias_method :body, :params

      def initialize(env, request, params, app)
        @env = env
        @request = request
        @params = params
        @header = {}
        @app = app
        parse_request
      end


      def execute
        request_block = wsdl.block
        @response = Soap::Response.new(wsdl, nil)
        response_hash = self.instance_eval(&request_block)

        if @response.params == nil
          if response_hash.is_a?(Array)
            @response.params, @response.headers = response_hash
          else
            @response.params = response_hash
          end
        end

        @response
      end

      alias_method :orig_params, :params

      def action
        return orig_params[:action] unless orig_params[:action].nil?
        orig_params[:action] = env['HTTP_SOAPACTION'].to_s.gsub(/^"(.*)"$/, '\1').to_sym
      end

      def params
        return orig_params[:soap] unless orig_params[:soap].nil?
        rack_input = env["rack.input"].read
        env["rack.input"].rewind
        orig_params[:soap] = nori.parse(rack_input)[:Envelope][:Body][action]
      end

      def header
        return orig_params[:soap_header] unless orig_params[:soap_header].nil?
        rack_input = env["rack.input"].read
        env["rack.input"].rewind
        orig_params[:soap_header] = nori.parse(rack_input)[:Envelope][:Header]
      end

      alias_method :soap_header, :header

      def wsdl
        @wsdl = Soap::Wsdl.new(action)
      end

      def method_missing(method_name, *args, &blok)
        @app.send(method_name, *args, &blok)
      end

      private

      def parse_request
        action
        params
      end

      def nori(snakecase=false)
        Nori.new(
          :strip_namespaces => true,
          :advanced_typecasting => true,
          :convert_tags_to => (
            snakecase ? lambda { |tag| tag.snakecase.to_sym } 
                      : lambda { |tag| tag.to_sym }
          )
        )
      end

    end
  end
end