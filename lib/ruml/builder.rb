module RUML
  # Understands a small DSL for UML modeled in subset of UML Substructure.
  class Builder
    attr_reader :created

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @created = [ ]
      @target = @opts[:target]
      raise ArgumentError, ":target not a Module" unless Module === @target
      @target_stack = [ ]
      instance_eval &blk if block_given?
    end

    def import *args
      $stderr.puts "  import #{args.inspect}"
      (@target.ruml[:import] ||= [ ]).push(*args).uniq!
      args.each do | x |
        x = _type(x)
        x.constants.each do | n |
          cv = x.const_get(n)
          $stderr.puts "  import #{@target}::#{n} = #{x}::#{n}"
          @target.const_set(n, cv)
        end
      end
    end

    def specialize *args
      (@target.ruml[:specialize] ||= [ ]).push(*args).uniq!
    end

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

    def _package name, *args, &blk
      _ :Package, name, *args, &blk
    end

    def _class name, *args, &blk
      _ :Class, name, *args, &blk
    end

    
    def _type type
      $stderr.puts "    _type(#{@target}, #{type.inspect})"
      case type
      when Module
        type
      when String, Symbol
        result = nil
        _decomp_path(@target).reverse.each do | o |
          o = o[-1]
          # $stderr.puts "  trying #{o} -> #{type}"
          result = eval("::#{o}::#{type}") rescue nil
          break if result
        end
        $stderr.puts "      #{@target}->#{type} => #{result}"
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
      expr = 
        case type
        when :Class
          "class  "
        when :Package
          "module "
        else
          raise ArgumentError, "invalid type #{type.inspect}"
        end
      expr = "#{path_b}; #{expr} #{name} ; end;  #{path_e}; ::#{@target}::#{name};"

      $stderr.puts "#{expr}"

      result = Kernel.eval(expr)

      $stderr.puts "#{result.inspect} { "
  
      @created << result

      if block_given?
        begin
          @target_stack.push @target
          @target = result
          instance_eval &blk
        ensure
          @target = @target_stack.pop
        end
      end

      pp result.ruml
      $stderr.puts "}"

      result
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

