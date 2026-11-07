# frozen_string_literal: true

require 'ruml'
require 'ruml/support'
require 'ruml/compiler'
require 'ruml/navigable'
require 'ruml/ast'
require 'ruml/logging'

module RUML

  # Understands a small DSL for UML modeled in subset of UML Substructure.
  class Builder
    attr_reader :created, :root, :namespace

    include AST::Repr, Logging
    alias_method :_repr, :namespace

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @_log_verbose = true # @opts[:verbose]
      @created = [ ]
      @root = @opts[:root] || AST::Node[meta: :root]
      @namespace = @root
      @namespace_stack = [ ]
      @result = instance_eval(&blk) if block_given?
    end

    def inspect detail=false
      return super() if detail
      "#<#{self.class} ...>"
    end

    def _log msg = nil
      if @verbose
        msg ||= yield if block_given?
        _log { "#{self.class}#{'  ' * @namespace_stack.size} #{msg}" }
      end
    end

    def _compile(opts = { })
      opts = @opts.merge(opts)
      c = Compiler.new(opts)
      c.compile(@root)
      c
    end

    def self.collector *names, &blk
      source_location = [__FILE__, __LINE__ - 1]
      names.each do |meta|
        raise "collector : #{meta} : unexpected block" if blk
        expr = <<"RUBY"
def #{meta} *args, &blk
  _make_node(:#{meta}, *args, &blk)
end
RUBY
        class_eval(expr, *source_location)
      end
    end

    def _make_node meta, *args, &blk
      _log { "#{meta} \#{args.inspect} \#{blk && '&blk'}" }
      name = args[0].to_s
      path = @namespace_stack.map(&:name).compact.join('::')
      obj = ::RUML::AST::Node[
        meta: meta,
        type: meta,
        name: name,
        args: args,
        blk: blk,
        namespace: @namespace,
        namespace_path: path,
        ownedElement: [],
        # owner: nil,
      ]
      (@namespace[name] ||= [ ]).push(obj).uniq!
      @created << obj
      obj
    end

    def _desc node
      path_str = node._namespace_str
      "#{self.class}._namespace : #{node.inspect} @ #{path_str}"
    end

    collector :import, :stereotype, :property, :association, :constant, :parameter, :generalization

    def package name, *args, &blk
      _namespace :package, name, args, &blk
    end

    def class_ name, *args, &blk
      _namespace :class, name, args, &blk
    end

    def method name, *args, &blk
      _namespace(:method, name, args) do | node |
        node.blk = blk
        # binding.pry
        node.parameter = blk.parameters.map do |(kind, name)|
          parameter name
        end
      end
    end

    def namespace_str path
      path.map{|node| node.name}.compact.map(&:to_s).join("::")
    end

    def _namespace type, name, args, instance_blk=nil, &inner_blk
      name = name.to_s.sub(/\A_/, '').to_sym
      raise "@namespace is nil" if @namespace.nil?

      node = _make_node(type, name, *args, &instance_blk)
      msg = "#{self.class}._namespace : #{_desc(node)}"
      puts(msg)
      _log { msg }

      @created << node
      (@namespace.ownedElement ||= []) << node
      @namespace_stack.push @namespace
      begin
        @namespace = node
        yield node if inner_blk
      ensure
        @namespace = @namespace_stack.pop
      end

      _log { "}" }

      node
    end

    def method_missing sel, *args, &blk
      sel_s = sel.to_s
      case sel_s
      when /\A([a-z0-9_]+)\Z/i
        case args.size
        when 0
          return @namespace[sel]
        when 1
          return @namespace[sel] = args.first
        end
      when /\A([a-z0-9_]+)=\Z/i
        case args.size
        when 1
          return @namespace[$1.to_sym] = args.first
        end
      end
      super
    end

  end # Builder
end # RUML

