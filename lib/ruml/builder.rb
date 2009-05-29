require 'ruml/support'

module RUML
  # Understands a small DSL for UML modeled in subset of UML Substructure.
  class Builder
    attr_reader :created

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @verbose = @opts[:verbose]
      @created = [ ]
      @root = @opts[:root] || { :meta => :root }
      @namespace = @root
      @namespace_stack = [ ]
      instance_eval &blk if block_given?
    end

    def _log msg = nil
      if @verbose 
        msg ||= yield if block_given?
        $stderr.puts "#{self.class}#{'  ' * @namespace_stack.size} #{msg}"
      end
    end

    def compile(opts)
      c = Compiler.new(opts)
      c.compile(@root)
      c
    end

    def self.collector *names
      names.each do | name |
        class_eval(expr = <<"RUBY", __FILE__, __LINE__)
def #{name} *args, &blk
  _log { "#{name} \#{args.inspect} \#{blk && '&blk'}" }
  obj = {:meta => :#{name}, :args => args, :blk => blk, :namespace => @namespace, }
  (@namespace[:#{name}] ||= [ ]).push(obj).uniq!
  @created << obj
  self
end
RUBY
        # $stderr.puts expr
      end
    end

    collector :import, :stereotype, :property, :association, :constant, :method

    def _package name, *args, &blk
      _namespace :package, name, *args, &blk
    end

    def _class name, *args, &blk
      _namespace :class, name, *args, &blk
    end

    def _namespace type, name, *args, &blk
      raise "@namespace is nil" if @namespace.nil?
      
      namespace = { :meta => type, :type => type, :name => name, :args => args }
      namespace[:path] = (@namespace_stack + [ @namespace, namespace ]).map{|x| x[:name]}.compact.join('::')

      _log { "#{namespace.inspect} { " }
  
      @created << namespace

      (@namespace[:ownedElement] ||= [ ]) << namespace
      namespace[:namespace] = @namespace

      if blk
        begin
          @namespace_stack.push @namespace
          @namespace = namespace
          instance_eval &blk
        ensure
          @namespace = @namespace_stack.pop
        end
      end

      _log { "}" }

      namespace
    end

    def method_missing sel, *args, &blk
      sel_s = sel.to_s
      case sel_s
      when /\A([a-z0-9_]+)\Z/i
        case args.size
        when 0
          @namespace[sel.to_sym]
        when 1
          @namespace[sel.to_sym] = args.first
        else
          super
        end
      when /\A([a-z0-9_]+)=\Z/i
        case args.size
        when 1
          @namespace[$1.to_sym] = args.first
        else
          super
        end
      else
        super
      end
    end

    class Compiler
      include RUML::Support::CodeGeneration
      EMPTY_ARRAY = [ ].freeze unless defined? EMPTY_ARRAY

      attr_reader :target, :pass

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
        @rep_path_to_module = { }
        raise ArgumentError, ":target not a Module" unless Module === @target
      end
      
      def _log msg = nil
        if @verbose 
          msg ||= yield if block_given?
          $stderr.puts "#{self.class} #{pass}#{'  ' * @current_stack.size} #{msg}"
        end
      end


      # Maps symbolic type to Ruby Class or Module.
      def _type type
        _log { "    _type(#{target}, #{type.inspect})" }
        case type
        when Module, nil
          type
        when String, Symbol
          result = nil
          _decomp_path(target).reverse.each do | o |
            o = o[-1]
            # _log { "  trying #{o} -> #{type}" }
            result = eval("::#{o}::#{type}") rescue nil
            break if result
          end
          _log { "      #{target}->#{type} => #{result}" }
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
        rep[:ownedElement].each { | x | compile(x) }
        @pass += 1
        rep[:ownedElement].each { | x | compile(x) }
      end

      def compile_class rep
        send("compile_namespace_#{pass}", rep)
      end

      def compile_package rep
        send("compile_namespace_#{pass}", rep)
      end

      def compile_namespace_1 rep
        raise "target is nil" if target.nil?
        type, name, args, blk = rep.project(:type, :name, :args, :blk)

        path = _decomp_path target
        pre = '::'
        path_b = path.map { | x | y = pre; pre = nil; " #{x[0]} #{y}#{x[1]} " }.join('; ')
        path_e = path.map { | x | " end " }.join('; ')
        def_args = nil
        expr = 
        case type
        when :class
          def_args = "< #{args * ' '}" unless args.empty?
          "class  "
        when :package
          "module "
        else
          raise ArgumentError, "invalid type #{type.inspect}"
        end # end
        
        expr = "#{path_b}; #{expr} #{name} #{def_args}; end;  #{path_e}; ::#{@target}::#{name};"
          
        _log { "#{expr}" }
          
        target = Kernel.eval(expr)
          
        _log { "#{target.inspect} { " }
          
        @created << target
          
        if type == :Class && ! rep[:isAbstract]
          target.instance_eval do 
            include RUML::Support::Instantiable
          end
        end
        
        @rep_path_to_module[rep[:path]] = target
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
          @target = @rep_path_to_module[rep[:path]]
          @current_stack.push @current
          @current = rep
          send("in_namespace_#{pass}", rep)
        ensure
          @target = @target_stack.pop
          @current = @current_stack.pop
        end
      end

      def in_namespace_1 rep
        [ :import, :property, :method, :constant, :ownedElement ].each do | k |
          (rep[k] || EMPTY_ARRAY).each do | x |
            compile x
          end
        end
      end

      def in_namespace_2 rep
        [ :ownedElement, :association ].each do | k |
          (rep[k] || EMPTY_ARRAY).each do | x |
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
        if args.include?(:class)
          target.meta_def name, &blk
        else
          target.class_def name, &blk
        end
        _log { "    => pim #{(target.public_instance_methods.sort - Object.methods).inspect}" }
        _log { "    => sm  #{(target.methods.sort - Object.methods).inspect}" }
      end

    end # Compiler

  end # Builder
end # RUML


class Hash
  def project *keys
    result = [ nil ] * keys.size
    keys.each_with_index { | k, i | result[i] = self[k] }
    result
  end
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


