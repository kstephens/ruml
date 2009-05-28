require 'ruml/support'

module RUML
  # Understands a small DSL for UML modeled in subset of UML Substructure.
  class Builder
    attr_reader :created

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @created = [ ]
      @target = @opts[:target]
      @verbose = @opts[:verbose]
      raise ArgumentError, ":target not a Module" unless Module === @target
      @target_stack = [ ]
      instance_eval &blk if block_given?
    end

    def _log msg = nil
      if @verbose 
        msg ||= yield if block_given?
        $stderr.puts "#{self.class} #{msg}"
      end
    end

    def import *args
      _log { "  import #{args.inspect}" }
      (@target.ruml[:import] ||= [ ]).push(*args).uniq!
      args.each do | x |
        x = _type(x)
        x.constants.each do | n |
          cv = x.const_get(n)
          _log { "  import #{@target}::#{n} = #{x}::#{n}" }
          @target.const_set(n, cv)
        end
      end
    end

=begin
    def specialize *args
      (@target.ruml[:specialize] ||= [ ]).push(*args).uniq!
    end
=end

    def stereotype *args
      (@target.ruml[:stereotype] ||= [ ]).push(*args).uniq!
    end

    def property *args
      args[1] = _type(args[1])
      (@target.ruml[:property] ||= [ ]).push(args)
    end

    def association *args
      (@target.ruml[:association] ||= [ ]).push(args)
    end

    def constant name, val = nil, &blk
      name = name.to_s
      unless @target.constants.include?(name)
        if block_given?
          val = @target.instance_eval &blk
        end
        _log { "  constant #{name.inspect} = #{val.inspect}" }
 
        @target.const_set(name, val)
 
        @target.meta_def(name) { || val }
        @target.class_def(name) { || val }

        (@target.ruml[:constant] ||= [ ]).push([ name, val ])
      end
    end

    def method name, *args, &blk
      _log { "  method #{name.inspect} #{args.inspect}" }
       if args.include?(:class)
        @target.meta_def name, &blk 
      else
        @target.class_def name, &blk
      end
      _log { "    => pim #{(@target.public_instance_methods.sort - Object.methods).inspect}" }
      _log { "    => sm  #{(@target.methods.sort - Object.methods).inspect}" }

      (@target.ruml[:method] ||= [ ]).push([ name, args ])
    end

    def _package name, *args, &blk
      _ :Package, name, *args, &blk
    end

    def _class name, *args, &blk
      _ :Class, name, *args, &blk
    end

    
    def _type type
      _log { "    _type(#{@target}, #{type.inspect})" }
      case type
      when Module
        type
      when String, Symbol
        result = nil
        _decomp_path(@target).reverse.each do | o |
          o = o[-1]
          # _log { "  trying #{o} -> #{type}" }
          result = eval("::#{o}::#{type}") rescue nil
          break if result
        end
        _log { "      #{@target}->#{type} => #{result}" }
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
    
    def _ type, name, *args, &blk
      raise "@target is nil" if @target.nil?
      
      path = _decomp_path @target
      pre = '::'
      path_b = path.map { | x | y = pre; pre = nil; " #{x[0]} #{y}#{x[1]} " }.join('; ')
      path_e = path.map { | x | " end " }.join('; ')
      def_args = nil
      expr = 
        case type
        when :Class
          def_args = "< #{args * ' '}" unless args.empty?
          "class  "
        when :Package
          "module "
        else
          raise ArgumentError, "invalid type #{type.inspect}"
        end

      expr = "#{path_b}; #{expr} #{name} #{def_args}; end;  #{path_e}; ::#{@target}::#{name};"

      _log { "#{expr}" }

      target = Kernel.eval(expr)

      _log { "#{target.inspect} { " }
  
      @created << target

      if block_given?
        begin
          @target_stack.push @target
          @target = target
          instance_eval &blk
        ensure
          @target = @target_stack.pop
        end
      end

      if type == :Class && ! target.ruml[:isAbstract]
        target.instance_eval do 
          include RUML::Support::Instantiable
        end
      end

      _log { "}" }

      target
    end

    def method_missing sel, *args, &blk
      sel_s = sel.to_s
      case sel_s
      when /\A([a-z0-9_]+)\Z/i
        case args.size
        when 0
          @target.ruml[sel.to_sym]
        when 1
          @target.ruml[sel.to_sym] = args.first
        else
          super
        end
      when /\A([a-z0-9_]+)=\Z/i
        case args.size
        when 1
          @target.ruml[$1.to_sym] = args.first
        else
          super
        end
      else
        super
      end
    end

    module ModuleHelper
      def ruml
        @ruml ||= { }
      end
    end
  end # Builder
end # RUML

Module.instance_eval do
  include RUML::Builder::ModuleHelper
end


# http://whytheluckystiff.net/articles/seeingMetaclassesClearly.html
class Object
  # The hidden singleton lurks behind everyone
  def metaclass
    class << self; self; end
  end
  def meta_eval &blk
    metaclass.instance_eval &blk
  end
  
  # Adds methods to a metaclass
  def meta_def name, &blk
    meta_eval { define_method name, &blk }
  end
  
  # Defines an instance method within a class
  def class_def name, &blk
    class_eval { define_method name, &blk }
  end
end



