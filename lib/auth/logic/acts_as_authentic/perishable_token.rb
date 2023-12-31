# frozen_string_literal: true

module Authentication
  module Logic
    module ActsAsAuthentic
      # This provides a handy token that is "perishable", meaning the token is
      # only good for a certain amount of time.
      #
      # This is useful for resetting password, confirming accounts, etc. Typically
      # during these actions you send them this token in an email. Once they use
      # the token and do what they need to do, that token should expire.
      #
      # Don't worry about maintaining the token, changing it, or expiring it
      # yourself. Authentication::Logic does all of this for you. See the sub modules for all
      # of the tools Authentication::Logic provides to you.
      module PerishableToken
        def self.included(klass)
          klass.class_eval do
            extend Config
            add_acts_as_authentic_module(Methods)
          end
        end

        # Configure the perishable token.
        module Config
          # When using the find_using_perishable_token method the token can
          # expire. If the token is expired, no record will be returned. Use this
          # option to specify how long the token is valid for.
          #
          # * <tt>Default:</tt> 10.minutes
          # * <tt>Accepts:</tt> Fixnum
          def perishable_token_valid_for(value = nil)
            rw_config(
              :perishable_token_valid_for,
              (!value.nil? && value.to_i) || value,
              10.minutes.to_i
            )
          end
          alias perishable_token_valid_for= perishable_token_valid_for

          # Authentication::Logic tries to expire and change the perishable token as much as
          # possible, without compromising its purpose. If you want to manage it
          # yourself, set this to true.
          #
          # * <tt>Default:</tt> false
          # * <tt>Accepts:</tt> Boolean
          def disable_perishable_token_maintenance(value = nil)
            rw_config(:disable_perishable_token_maintenance, value, false)
          end
          alias disable_perishable_token_maintenance= disable_perishable_token_maintenance
        end

        # All methods relating to the perishable token.
        module Methods
          def self.included(klass)
            return unless klass.column_names.include?("perishable_token")

            klass.class_eval do
              extend ClassMethods
              include InstanceMethods

              validates_uniqueness_of :perishable_token, case_sensitive: true,
                                                         if: :will_save_change_to_perishable_token?
              before_save :reset_perishable_token, unless: :disable_perishable_token_maintenance?
            end
          end

          # :nodoc:
          module ClassMethods
            # Use this method to find a record with a perishable token. This
            # method does 2 things for you:
            #
            # 1. It ignores blank tokens
            # 2. It enforces the perishable_token_valid_for configuration option.
            #
            # If you want to use a different timeout value, just pass it as the
            # second parameter:
            #
            #   User.find_using_perishable_token(token, 1.hour)
            def find_using_perishable_token(token, age = perishable_token_valid_for)
              return if token.blank?

              age = age.to_i

              conditions_sql = "perishable_token = ?"
              conditions_subs = [token.to_s]

              if column_names.include?("updated_at") && age.positive?
                conditions_sql += " and updated_at > ?"
                conditions_subs << age.seconds.ago
              end

              where(conditions_sql, *conditions_subs).first
            end

            # This method will raise ActiveRecord::NotFound if no record is found.
            def find_using_perishable_token!(token, age = perishable_token_valid_for)
              find_using_perishable_token(token, age) || raise(ActiveRecord::RecordNotFound)
            end
          end

          # :nodoc:
          module InstanceMethods
            # Resets the perishable token to a random friendly token.
            def reset_perishable_token
              self.perishable_token = Random.friendly_token
            end

            # Same as reset_perishable_token, but then saves the record afterwards.
            def reset_perishable_token!
              reset_perishable_token
              save_without_session_maintenance(validate: false)
            end

            # A convenience method based on the
            # disable_perishable_token_maintenance configuration option.
            def disable_perishable_token_maintenance?
              self.class.disable_perishable_token_maintenance == true
            end
          end
        end
      end
    end
  end
end
