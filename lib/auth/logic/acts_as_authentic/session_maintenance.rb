# frozen_string_literal: true

module Authentication
  module Logic
    module ActsAsAuthentic
      # This is one of my favorite features that I think is pretty cool. It's
      # things like this that make a library great and let you know you are on the
      # right track.
      #
      # Just to clear up any confusion, Authentication::Logic stores both the record id and
      # the persistence token in the session. Why? So stale sessions can not be
      # persisted. It stores the id so it can quickly find the record, and the
      # persistence token to ensure no sessions are stale. So if the persistence
      # token changes, the user must log back in.
      #
      # Well, the persistence token changes with the password. What happens if the
      # user changes his own password? He shouldn't have to log back in, he's the
      # one that made the change.
      #
      # That being said, wouldn't it be nice if their session and cookie
      # information was automatically updated? Instead of cluttering up your
      # controller with redundant session code. The same thing goes for new
      # registrations.
      #
      # That's what this module is all about. This will automatically maintain the
      # cookie and session values as records are saved.
      module SessionMaintenance
        def self.included(klass)
          klass.class_eval do
            extend Config
            add_acts_as_authentic_module(Methods)
          end
        end

        # Configuration for the session maintenance aspect of acts_as_authentic.
        # These methods become class methods of ::ActiveRecord::Base.
        module Config
          # In order to turn off automatic maintenance of sessions
          # after create, just set this to false.
          #
          # * <tt>Default:</tt> true
          # * <tt>Accepts:</tt> Boolean
          def log_in_after_create(value = nil)
            rw_config(:log_in_after_create, value, true)
          end
          alias log_in_after_create= log_in_after_create

          # In order to turn off automatic maintenance of sessions when updating
          # the password, just set this to false.
          #
          # * <tt>Default:</tt> true
          # * <tt>Accepts:</tt> Boolean
          def log_in_after_password_change(value = nil)
            rw_config(:log_in_after_password_change, value, true)
          end
          alias log_in_after_password_change= log_in_after_password_change

          # As you may know, auth-logic sessions can be separate by id (See
          # Authentication::Logic::Session::Base#id). You can specify here what session ids
          # you want auto maintained. By default it is the main session, which has
          # an id of nil.
          #
          # * <tt>Default:</tt> [nil]
          # * <tt>Accepts:</tt> Array
          def session_ids(value = nil)
            rw_config(:session_ids, value, [nil])
          end
          alias session_ids= session_ids

          # The name of the associated session class. This is inferred by the name
          # of the model.
          #
          # * <tt>Default:</tt> "#{klass.name}Session".constantize
          # * <tt>Accepts:</tt> Class
          def session_class(value = nil)
            const = begin
              "#{base_class.name}Session".constantize
            rescue NameError
              nil
            end
            rw_config(:session_class, value, const)
          end
          alias session_class= session_class
        end

        # This module, as one of the `acts_as_authentic_modules`, is only included
        # into an ActiveRecord model if that model calls `acts_as_authentic`.
        module Methods
          def self.included(klass)
            klass.class_eval do
              before_save :get_session_information, if: :update_sessions?
              before_save :maintain_sessions, if: :update_sessions?
            end
          end

          # Save the record and skip session maintenance all together.
          def save_without_session_maintenance(**options)
            self.skip_session_maintenance = true
            result = save(**options)
            self.skip_session_maintenance = false
            result
          end

          private

          def skip_session_maintenance=(value)
            @skip_session_maintenance = value
          end

          def skip_session_maintenance
            @skip_session_maintenance ||= false
          end

          def update_sessions?
            !skip_session_maintenance &&
              session_class &&
              session_class.activated? &&
              maintain_session? &&
              !session_ids.blank? &&
              will_save_change_to_persistence_token?
          end

          def maintain_session?
            log_in_after_create? || log_in_after_password_change?
          end

          def get_session_information
            # Need to determine if we are completely logged out, or logged in as
            # another user.
            @_sessions = []

            session_ids.each do |session_id|
              session = session_class.find(session_id, self)
              @_sessions << session if session&.record
            end
          end

          def maintain_sessions
            if @_sessions.empty?
              create_session
            else
              update_sessions
            end
          end

          def create_session
            # We only want to automatically login into the first session, since
            # this is the main session. The other sessions are sessions that
            # need to be created after logging into the main session.
            session_id = session_ids.first
            session_class.create(*[self, self, session_id].compact)

            true
          end

          def update_sessions
            # We found sessions above, let's update them with the new info
            @_sessions.each do |stale_session|
              next if stale_session.record != self

              stale_session.unauthorized_record = self
              stale_session.save
            end

            true
          end

          def session_ids
            self.class.session_ids
          end

          def session_class
            self.class.session_class
          end

          def log_in_after_create?
            new_record? && self.class.log_in_after_create
          end

          def log_in_after_password_change?
            persisted? &&
              will_save_change_to_persistence_token? &&
              self.class.log_in_after_password_change
          end
        end
      end
    end
  end
end
