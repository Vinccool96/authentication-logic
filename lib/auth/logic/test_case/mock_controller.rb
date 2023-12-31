# frozen_string_literal: true

module Authentication
  module Logic
    module TestCase
      # Basically acts like a controller but doesn't do anything. Authentication::Logic can interact
      # with this, do it's thing and then you can look at the controller object to see if
      # anything changed.
      class MockController < ControllerAdapters::AbstractAdapter
        attr_accessor :http_user, :http_password, :realm
        attr_writer :request_content_type

        def initialize; end

        def authenticate_with_http_basic
          yield http_user, http_password
        end

        def authenticate_or_request_with_http_basic(realm = "DefaultRealm")
          self.realm = realm
          @http_auth_requested = true
          yield http_user, http_password
        end

        def cookies
          @cookies ||= MockCookieJar.new
        end

        def cookie_domain
          nil
        end

        def logger
          @logger ||= MockLogger.new
        end

        def params
          @params ||= {}
        end

        def request
          @request ||= MockRequest.new(self)
        end

        def request_content_type
          @request_content_type ||= "text/html"
        end

        def session
          @session ||= {}
        end

        def http_auth_requested?
          @http_auth_requested ||= false
        end
      end
    end
  end
end
