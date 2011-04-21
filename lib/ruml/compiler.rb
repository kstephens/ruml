require 'ruml'
require 'ruml/support'

module RUML
  class Compiler
      include RUML::Support::CodeGeneration
      EMPTY_ARRAY = [ ].freeze unless defined? EMPTY_ARRAY

      # Inputs:
      attr_reader :target, :pass
      
      # Outputs:
      attr_reader :created, :path_to_module

      def initialize opts = nil, &blk
        opts ||= { } # EMPTY_HASH
        @opts = opts
        @verbose = @opts[:verbose]
        @created = [ ]
        @target = @opts[:target]
        @target_stack = [ ]
        @current = nil
        @current_stack = [ ]
        @pass = 1
        @path_to_module = { }
        raise ArgumentError, ":target #{@target} not a Module" unless Module === @target
      end
      
      def _log msg = nil
        if @verbose 
          msg ||= yield if block_given?
          $stderr.puts "#{self.class} #{pass}#{'  ' * @current_stack.size} #{msg}"
        end
      end


      # Maps symbolic type to Ruby Class or Module.
      def _type type
        # _log { "    _type(#{target}, #{type.inspect})" }
        case type
        when Module, nil
          type
        when String, Symbol
          type = type.to_s
          result = nil
          _decomp_path(target).reverse.each do | o |
            o = o[-1]
            # _log { "  trying #{o} -> #{type}" }
            result = eval("::#{o}") rescue nil
            if result.constants.include?(type)
              result = result.const_get(type) rescue nil
              break
            end
          end
          # _log { "      #{target}->#{type} => #{result}" }
          result
        else
          raise ArgumentError, "type #{type.inspect}"
        end
      end
      
      def _decomp_path path
        result = [ ]
        path.to_s.split('::').inject(Kernel) do | o, n |
          o = o.const_get(n)
          result <<
            case o
            when Class
              [ :class, n, o ]
            when Module
              [ :module, n, o ]
            else
              raise TypeError, "Unexpected #{o.inspect}"
            end
          o
        end
        result
      end
      

      def compile x
        handler = nil
        [ "compile_#{x[:meta]}_#{pass}", "compile_#{x[:meta]}" ].each do | sel |
          if respond_to?(sel)
            handler = sel
            _log { "#{sel} #{x[:meta].inspect} #{x[:args].inspect}" }
            send(sel, x)
            break
          end
        end
        unless handler
          _log { "WARNING no handler for #{x[:meta]}" }
        end
      end


      def compile_root rep
        (rep[:ownedElement] || EMPTY_Array).each { | x | compile(x) }
        @pass += 1
        (rep[:ownedElement] || EMPTY_Array).each { | x | compile(x) }
      end

      def compile_class rep
        send("compile_namespace_#{pass}", rep)
      end

      def compile_package rep
        send("compile_namespace_#{pass}", rep)
      end

      def _generalization rep
        (rep[:generalization] || EMPTY_Array).
          map{|x| x[:args]}.
          flatten.
          map{|x| _type(x)}
      end

      def compile_namespace_1 rep
        raise "target is nil" if target.nil?
        type, name, args, blk = rep.project(:type, :name, :args, :blk)

        path = _decomp_path target
        pre = '::'
        path_b = path.map { | x | y = pre; pre = nil; " #{x[0]} #{y}#{x[1]} " }.join('; ')
        path_e = path.map { | x | " end " }.join('; ')

        g = _generalization rep

        _log { "  g = #{g.inspect}" } unless g.empty?

        def_args = nil
        inside = nil

        expr = 
        case type
        when :class
          if rep[:isAbstract]
            "module "
          else
            first_class = g.find{|x| Class === x}
            if first_class
              def_args = " < ::#{first_class}"
              g.delete(first_class)
            end
            inside = "module Behavior; end; include Behavior; module ClassBehavior; end; extend ClassBehavior"
            "class  "
          end
        when :package
          "module "
        else
          raise ArgumentError, "invalid type #{type.inspect}"
        end # end
        
        expr = "#{path_b}; #{expr} #{name} #{def_args}; #{inside} end;  #{path_e}; ::#{@target}::#{name};"
          
        _log { "#{expr}" }
          
        target = Kernel.eval(expr)
        @created << target
       
        _log { "#{target.inspect} { " }  
        
        # If it's a non-abstract class, make it instantiable.
        if Class == target && ! rep[:isAbstract]
          target.instance_eval do 
            _log { "  include RUML::Support::Instantiable" }
            include RUML::Support::Instantiable
          end
        end

        # Add generalizations.
        this = self
        g.each do | x |
          target.instance_eval do
            case x
            when Class
              # x = x.const_get('Behavior')
            end
            this._log { "  include #{x}" }
            include x
          end
        end
         
        @path_to_module[rep[:path]] = target
        inside_namespace rep

        _log { "}" }
        
        target
      end
        
      def compile_namespace_2 rep
        inside_namespace rep
      end

      def inside_namespace rep
        begin
          @target_stack.push @target
          @target = @path_to_module[rep[:path]]
          @current_stack.push @current
          @current = rep
          send("in_namespace_#{pass}", rep)
        ensure
          @target = @target_stack.pop
          @current = @current_stack.pop
        end
      end

      def in_namespace_1 rep
        [ :stereotype, :import, :property, :method, :constant, :ownedElement ].each do | k |
          (rep[k] || EMPTY_Array).each do | x |
            compile x
          end
        end
      end

      def in_namespace_2 rep
        [ :ownedElement, :association ].each do | k |
          (rep[k] || EMPTY_Array).each do | x |
            compile x
          end
        end
      end

      def compile_constant rep
        (name, val), blk = rep.project(:args, :blk)
        name = name.to_s
        unless target.constants.include?(name)
          if block_given?
            val = target.instance_eval &blk
          end
          _log { "  constant #{rep[:name].inspect} = #{rep[:val].inspect}" }
          
          target.const_set(name, val)
          
          target.meta_def(name) { || val }
          target.class_def(name) { || val }
        end
      end

      def compile_import rep
        args = rep.project(:args)
        args.flatten.each do | x |
          x = _type(x)
          x.constants.each do | n |
            cv = x.const_get(n)
            _log { "  import #{target}::#{n} = #{x}::#{n}" }
            target.const_set(n, cv)
          end
        end
      end

      def compile_stereotype rep
        args = rep[:args]
        @target.stereotype *args
      end

      def compile_property rep
        args = rep[:args].dup
        args[1] = _type(args[1]) || (raise "Cannot find type for #{rep.inspect}")
        _generate_property target, *args
      end

      def compile_association rep
        args = rep[:args].dup
        args[1] = _type(args[1]) || target
        args[5] = _type(args[5]) || target
        _generate_association *args
      end

      def compile_method rep
        args, blk = rep.project(:args, :blk)
        args = args.dup
        name = args.shift
        
        t = target

        if args.include?(:class)
          # t = target.const_get("ClassBehavior") if Class == target
          t.meta_def name, &blk
        else
          # t = target.const_get("Behavior") if Class == target
          t.class_def name, &blk
        end

        _log { "    => pim #{(t.public_instance_methods.sort - Object.methods).inspect}" }
        _log { "    => sm  #{(t.methods.sort - Object.methods).inspect}" }
      end

    end # Compiler
end # RUML


