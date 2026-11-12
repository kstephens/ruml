
require 'ruml'
require 'ruml/xmi/introspection'
require 'ruml/support/traverser'
require 'ruml/support/logging'

module RUML
  module Support
    module Initialize
      def initialize opts=nil
        initialize_opts opts
      end
      def initialize_opts opts=nil
        @opts = default_opts.merge(opts || {})
        @opts.each do | k, v |
          setter = :"#{k}="
          if respond_to?(setter)
            send(setter, v)
          else
            instance_variable_set(:"@#{k}", v)
          end
        end
      end
      def default_opts
        {}
      end

      # def self.included target
      #   super
      #   target.extend ModuleMethods
      # end
      # module ModuleMethods
      #   def properties; @properties = {} ;end
      #   def property name, default
      #     @@properties
      #   end
      # end
    end
  end
end
