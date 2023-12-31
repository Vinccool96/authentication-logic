# frozen_string_literal: true

module Authentication
  module Logic
    module ActsAsAuthentic
      # Magic columns are like ActiveRecord's created_at and updated_at columns.
      # They are "magically" maintained for you. Authentication::Logic has the same thing, but
      # these are maintained on the session side. Please see "Magic Columns" in
      # `Session::Base` for more details. This module merely adds validations for
      # the magic columns if they exist.
      module MagicColumns
        def self.included(klass)
          klass.class_eval do
            add_acts_as_authentic_module(Methods)
          end
        end

        # Methods relating to the magic columns
        module Methods
          def self.included(klass)
            klass.class_eval do
              if column_names.include?("login_count")
                validates_numericality_of :login_count,
                                          only_integer: true,
                                          greater_than_or_equal_to: 0,
                                          allow_nil: true
              end
              if column_names.include?("failed_login_count")
                validates_numericality_of :failed_login_count,
                                          only_integer: true,
                                          greater_than_or_equal_to: 0,
                                          allow_nil: true
              end
            end
          end
        end
      end
    end
  end
end
