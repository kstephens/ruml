require 'ruml/support'
require 'ruml/compiler'

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
  obj = { :meta => :#{name}, :args => args, :blk => blk, :namespace => @namespace, }
  (@namespace[:#{name}] ||= [ ]).push(obj).uniq!
  @created << obj
  self
end
RUBY
        # $stderr.puts expr
      end
    end

    collector :import, :stereotype, :property, :association, :constant, :method, :generalization

    def package name, *args, &blk
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

  end # Builder
end # RUML


