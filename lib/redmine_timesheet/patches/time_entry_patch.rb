module RedmineTimesheet
  module Patches
    module TimeEntryPatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
      end

      module ClassMethods
      end

      module InstanceMethods
        def invoice_amount
          invoice_price.value.to_i * invoice_quantity
        end

        def invoice_quantity
          -hours
        end

        def invoice_price
          project.custom_value_for(10)
        end
      end
    end
  end
end
