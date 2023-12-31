# frozen_string_literal: true

module Authentication
  module Logic
    module ControllerAdapters # :nodoc:
      # Allows you to use Authentication::Logic in any framework you want, not just rails. See
      # the RailsAdapter for an example of how to adapt Authentication::Logic to work with
      # your framework.
      class AbstractAdapter
        E_COOKIE_DOMAIN_ADAPTER = "The cookie_domain method has not been " \
          "implemented by the controller adapter"
        ENV_SESSION_OPTIONS = "rack.session.options"

        attr_accessor :controller

        def initialize(controller)
          self.controller = controller
        end

        def authenticate_with_http_basic
          @auth = Rack::Auth::Basic::Request.new(controller.request.env)
          if @auth.provided? && @auth.basic?
            yield(*@auth.credentials)
          else
            false
          end
        end

        def cookies
          controller.cookies
        end

        def cookie_domain
          raise NotImplementedError, E_COOKIE_DOMAIN_ADAPTER
        end

        def params
          controller.params
        end

        def request
          controller.request
        end

        def request_content_type
          request.content_type
        end

        # Inform Rack that we would like a new session ID to be assigned. Changes
        # the ID, but not the contents of the session.
        #
        # The `:renew` option is read by `rack/session/abstract/id.rb`.
        #
        # This is how Devise (via warden) implements defense against Session
        # Fixation. Our implementation is copied directly from the warden gem
        # (set_user in warden/proxy.rb)
        def renew_session_id
          env = request.env
          options = env[ENV_SESSION_OPTIONS]
          return unless options

          if options.frozen?
            env[ENV_SESSION_OPTIONS] = options.merge(renew: true).freeze
          else
            options[:renew] = true
          end
        end

        def session
          controller.session
        end

        def responds_to_single_access_allowed?
          controller.respond_to?(:single_access_allowed?, true)
        end

        def single_access_allowed?
          controller.send(:single_access_allowed?)
        end

        # You can disable the updating of `last_request_at`
        # on a per-controller basis.
        #
        #   # in your controller
        #   def last_request_update_allowed?
        #     false
        #   end
        #
        # For example, what if you had a javascript function that polled the
        # server updating how much time is left in their session before it
        # times out. Obviously you would want to ignore this request, because
        # then the user would never time out. So you can do something like
        # this in your controller:
        #
        #   def last_request_update_allowed?
        #     action_name != "update_session_time_left"
        #   end
        #
        # See `auth/logic/session/magic_columns.rb` to learn more about the
        # `last_request_at` column itself.
        def last_request_update_allowed?
          if controller.respond_to?(:last_request_update_allowed?, true)
            controller.send(:last_request_update_allowed?)
          else
            true
          end
        end

        def respond_to_missing?(*args)
          super(*args) || controller.respond_to?(*args)
        end

        private

        def method_missing(id, *args, &block)
          controller.send(id, *args, &block)
        end
      end
    end
  end
end
