# frozen_string_literal: true

require 'ruml/compiler/target'
require 'ruml/support/initialize'
require 'ruml/support/misc'
require 'method_source'
require 'ripper'

module RUML::Compiler
  class Target::Ruby < Target
    UNLIMITED = 12345678901234567890
    STAR = UNLIMITED

    include RUML::Support::Misc

    Instantiable = ::RUML::Core::Runtime::Instantiable
    Uninstantiatable = ::RUML::Core::Runtime::Uninstantiatable
    Import = RUML::Core::Runtime::Import
    Enumeration = RUML::Core::Runtime::Enumeration

    def emit_preamble(node)
      self << "require 'ruml/core/runtime'\n"
    end

    def emit_postamble(node)
    end

    def emit_root(_node)
      ns = frontend.root_namespace
      case ns
      when ::Class
        ns = "class #{ns}"
      when ::Module
        ns = "module #{ns}"
      end
      self << "#{ns}\n" if ns
      yield
      self << "end # #{ns}\n" if ns
    end

    def emit_namespace(node)
      path = navigator.namespace_path(node)
      path_str = navigator.path_str(node)
      kind = META_TO_MODULE_CLASS.fetch(node._.meta)
      declaration = "#{kind} #{path_str}"

      node._.to_h.update(
        path: path,
        path_str: path_str,
        ruby_instance_behavior: "#{path_str}::RUML_InstanceBehavior",
        ruby_module_behavior: "#{path_str}::RUML_ModuleBehavior",
        ruby_module_kind: kind,
        ruby_declaration: declaration,
        ruby_declaration_full: "#{kind} #{path_str}",
      )
      log { "#{path_str} { " }

      if node._.meta == :Class
        supers = node.superClass.map do |name|
          or_die(find_node_scoped(node.namespace, name)) do
            "class #{node.name} : cannot find superclass #{name.inspect}"
          end
        end
        # supers = node.superClass.dup
        if (super_ = supers.shift)
          super_path_str = navigator.path_str(super_)
          declaration << " < #{super_path_str}"
        end
        node._.superClass_remaining = supers
      end

      line! "##RUML #{node._.meta} #{node.name}"
      node.stereotype&.each do | st |
        line! "##RUML stereotype <<#{st.name}>>"
      end
      line! declaration
      line! "  module RUML_InstanceBehavior"
      line! "  end"
      line! "  module RUML_ModuleBehavior"
      emit_enumeration(node)
      node.ownedAttribute&.each do | prop |
        line! generate_property(prop)
      end
      line! "  end"
      line! "  def self.included(target)"
      line! "    target.include(RUML_InstanceBehavior)"
      line! "    target.extend(RUML_ModuleBehavior)"
      line! "  end"
      node._.ruby_include&.each do | m |
        line! "  include #{m}"
      end
      node._.ruby_extend&.each do | m |
        line! "  extend #{m}"
      end
      line! "  self"
      line! "end"
      line! ""
    end

    def emit_import node
      dst_path = module_path(node)
      node.importedPackage&.each do | src |
        # binding.pry
        src_path = module_path(src)
        line! "#{Import}.import(::#{dst_path}, ::#{src_path})"
      end
    end

    def emit_enumeration node
      names = (node.ownedLiteral || []).map(&:name)
      return "" if names.empty?
      line!
      line! "  include(#{Enumeration})"
      line! "  def self.enumeration_names"
      line! "    @__enumeration_names__ ||= #{names.inspect}.map!(&:freeze).freeze"
      line! "  end"
      line!
    end

    def emit_generalization node
      node_path = navigator.path_str(node)
      parent = node.namespace
      generals = (node.generalization || []).map(&:general)
      generals.map! do |g|
        node = find_node_scoped(parent, g)
        navigator.path_str(node)
      end
      if node._.isAbstract
        line! "#{node_path}.include(#{Uninstantiable})"
      else
        line! "#{node_path}.include(#{Instantiable})"
      end
      node._.superClass_remaining&.each do | super_ |
        gen_path = navigator.path_str(find_node_scoped(parent, super_))
        line! "#{node_path}.include(#{gen_path}::RUML_InstanceBehavior)"
      end
      generals.each do | gen_path |
        line! "#{node_path}.include(#{gen_path}::RUML_InstanceBehavior)"
      end
      line! "#{node_path}.include(#{node_path}::RUML_InstanceBehavior)"
      line! "#{node_path}.extend(#{node_path}::RUML_ModuleBehavior)"
    end

    def emit_operation(node)
      name = node.name.to_sym
      body = node.body
      if ! body && node._.blk
        body = extract_method_body(node._.blk.source.to_s)
      end
      line! "module ", path_module(node)
      self << <<"RUBY"
def #{name}
  #{body}
end
RUBY
      self << "end\n"
    end

    # Returns the body of the first do...end or {...} block in +code+,
    # without the block parameters or any trailing text after the block.
    def extract_method_body(code)
      opener_end = nil
      offset = 0
      Ripper.lex(code).each do | (_pos, type, tok, _state) |
        start = offset
        offset += tok.length
        opener_end ||= offset if (type == :on_kw && tok == "do") || type == :on_lbrace
        next unless opener_end && start >= opener_end
        next unless (type == :on_kw && tok == "end") || type == :on_rbrace
        next unless Ripper.sexp(code[0, offset])
        body = code[opener_end...start].sub(/\A\s*\|[^|]*\|/, "")
        return body.sub(/\A[\s;]+/, "").sub(/[\s;]+\z/, "")
      end
      raise ArgumentError, "no block found in #{code.inspect}"
    end

    def emit_constant(node)
      name_upper = node.name.to_s.upper
      line! "module " << path_module(node)
      if method
          line! <<"RUBY"
        def self.#{node.name} ; #{name_upper} ; end
        def #{node.name} : #{name_upper} ; end
RUBY
      end
      line! "#{name_upper} = #{value}"
      line! "end"
    end

    def emit_property node
      line! generate_property(node)
    end

    def generate_property node, opts = {}
      node_path = namespace_str(node.class)
      type_node = node.type
      binding.pry if ::Array === type_node
      type_node = type_node[0] if ::Array === type_node # !!!
      type_name = namespace_str(type_node)
      opts = {primitive: hasStereotype?(type_node, :primitive)}.merge(opts)
      name, type, lower, upper, default =
        node.name, type_name, node.lower, node.upper, node.default

      desc = "Property : #{node_path}::#{name} : #{type} #{lower}..#{upper < 0 ? "*" : upper}"
      desc << " = #{default}" unless default.nil?

      name = fix_name(name)

      if opts[:primitive]
        coerce = lambda { | _msg |
          <<"RUBY"
__val = #{type}.coerce(__val) unless __val.nil?
RUBY
        }
        typecheck = LAMBDA_NIL
      else
        coerce = LAMBDA_NIL
        typecheck = lambda { | msg |
          <<"RUBY"
raise ::ArgumentError, "#{msg}: #{desc} : expected #{type}" unless __val.nil? || #{type} === __val
RUBY
        }
      end

      typecheck_min = if lower == 1
        lambda { | msg |
          <<"RUBY"
raise ::ArgumentError, "#{msg}: #{desc}" if __val.nil?
RUBY
        }
      else
        LAMBDA_NIL
      end

      multiplicity_min = if lower > 0
        lambda { | msg, size |
          <<"RUBY"
raise ::ArgumentError, "#{msg}: #{desc}" unless #{size} >= #{lower}
RUBY
          }
      else
        LAMBDA_NIL
      end

      multiplicity_max = unless upper < 0 || upper == UNLIMITED
        lambda { | msg, size |
          <<"RUBY"
raise ::ArgumentError, "#{msg}: #{desc}" unless #{size} <= #{upper}
RUBY
          }
      else
        LAMBDA_NIL
      end

      typecheck = LAMBDA_NIL unless type

      default = "||= #{default.inspect}" unless default.nil?

      code = "  ##RUML #{desc}\n"
      case upper
      when 1
        code << <<"RUBY"
  def #{name}
    @#{name} #{default}
  end
  def #{name}_multi!
    @#{name}.nil? ? [ ] : [ @#{name} ]
  end
  def #{name}_count!
    #{name}.nil? ? 0 : 1
  end
  def #{name}= __val
    # coerce
    #{coerce.call("#{name}=")}
    # typecheck_min
    #{typecheck_min.call("#{name}=")}
    # typecheck
    #{typecheck.call("#{name}=")}
    #{name}_clear!
    @#{name} = __val
  end
  def #{name}_clear!
    @#{name} = nil
    self
  end
  def #{name}_add! __val
    return self if __val.nil?
    # coerce
    #{coerce.call("#{name}_add!")}
    # typecheck
    #{typecheck.call("#{name}_add!")}
    if @#{name} != __val
      # multiplicity_max
      #{multiplicity_max.call("#{name}_add!", "#{name}_count! + 1")}
      @#{name} = __val
    end
    self
  end
  def #{name}_remove! __val
    return self if __val.nil?
    # coerce
    #{coerce.call("#{name}_remove!")}
    # typecheck
    #{typecheck.call("#{name}_remove!")}
    if @#{name} == __val
      # multiplicity_min
      #{multiplicity_min.call("#{name}=", "#{name}_count! - 1")}
      @#{name} = nil
    end
    self
  end
RUBY
      else
        code << <<"RUBY"
  def #{name}
    @#{name} ||= [ ]
  end
  def #{name}_multi!
    @#{name}
  end
  def #{name}_count!
    #{name}.size
  end
  def #{name}= __vals
    # multiplicity_min
    #{multiplicity_min.call("#{name}=", "__vals.size")}
    # multiplicity_max
    #{multiplicity_max.call("#{name}=", "__vals.size")}
    #{name}_clear!
    __vals.each { | __val | #{name}_add!(__val) }
  end
  def #{name}_clear!
    #{name}.clear
    self
  end
  def #{name}_add! __val
    return self if __val.nil?
    # coerce
    #{coerce.call("#{name}_add!")}
    # typecheck
    #{typecheck.call("#{name}_add!")}
    # multiplicity_max
    #{multiplicity_max.call("#{name}_add!", "#{name}_count + 1")}
    #{name}.push(__val)
    self
  end
  def #{name}_remove! __val
    return self if __val.nil?
    # coerce
    #{coerce.call("#{name}_remove!")}
    # typecheck
    #{typecheck.call("#{name}_remove!")}
    # multiplicity_min
    #{multiplicity_min.call("#{name}=", "#{name}_count - 1")}
    #{name}.delete(__val)
    self
  end
RUBY
      end
      code
    end

    def path_module(node)
      result = _path_module(node)
      result
    end
    def _path_module(node)
      parent = node.namespace
      node._.isStatic ? parent._.ruby_module_behavior : parent._.ruby_instance_behavior
    end

    def emit_association node
      e = node
      o = e.opposite or raise
      binding.pry
      upper = o.upper
      upper = :* if upper < 0
      args = [o.name, o.type, o.lower, upper, o.subsets, e.name, e.type ]
      desc = "Association : #{e.type}.#{o.name} : #{o.type} #{o.lower}..#{upper}"
      code = "  ##RUML #{desc}\n"
      if upper == 1
        code << generate_association_1(*args)
      else
        code << generate_association_N(*args)
      end
      line! code
    end

    def generate_association_1 name, type, lower, upper, subsets, ename, etype
      name = fix_name(name)
      code = <<"RUBY"
  def #{name}
    @#{name}
  end
  def #{name}_count!
    @#{name}.nil? ? 0 : 1
  end
  def #{name}_multi!
    @#{name}.nil? ? [ ] : [ @#{name} ]
  end
  def #{name}= __val
    raise ArgumentError, "#{name}: expected #{type}" unless __val.nil? || #{type} === __val
    #{name}_clear!
    #{name}_add!(__val)
  end
  def #{name}_clear!
    #{name}_remove!(@#{name})
  end
  def #{name}_add!(__val)
    return self if __val.nil?
    unless @#{name} == __val
      raise ArgumentError, "#{name}_add!: already set" unless @#{name}.nil?
      @#{name} = __val
      #{generate_subsets(subsets, "_add!")}
      __val.#{ename}_add!(self)
    end
    self
  end
  def #{name}_remove!(__val)
    return self if __val.nil?
    if @#{name} == __val
      raise ArgumentError, "#{name}_remove!: expected #{type}" unless #{type} === __val
      @#{name} = nil
      #{generate_subsets(subsets, "_remove!")}
      __val.#{ename}_remove!(self)
    end
    self
  end
RUBY
      code
    end

    def generate_association_N name, type, lower, upper, subsets, ename, etype
      name = fix_name(name)
      code = <<"RUBY"
  def #{name}
    @#{name} ||= [ ]
  end
  def #{name}_count!
    #{name}.size
  end
  alias :#{name}_multi! :#{name}
  def #{name}=(__vals)
    #{name}_clear!
    __vals.each { | __val | #{name}_add!(__val) }
    self
  end
  def #{name}_clear!
    #{name}.dup.each { | __val | #{name}_remove!(__val) }
    self
  end
  def #{name}_add! __val
    return self if __val.nil?
    raise ArgumentError, "#{name}_add!: expected #{type}" unless #{type} === __val
    __cur = #{name}
    unless __cur.include?(__val)
      __cur.push(__val)
      #{generate_subsets(subsets, "_add!")}
      __val.#{ename}_add!(self)
    end
    self
  end
  def #{name}_remove! __val
    return self if __val.nil?
    raise ArgumentError, "#{name}_remove!: expected #{type}" unless #{type} === __val
    __cur = #{name}
    if __cur.include?(__val)
      __cur.delete(__val)
      #{generate_subsets(subsets, "_remove!")}
      __val.#{ename}_remove!(self)
    end
    self
  end
RUBY
      code
    end

    def generate_subsets subsets, suffix
      subsets.map do |subset|
        "#{subset}#{suffix}(__val) ##RUML subsets #{subset}"
      end * "\n      "
    end

    def coerce_multiplicity_value x
      case x
      when nil, Integer then x
      when :*, '*'      then UNLIMITED
      when String       then Integer(x)
      end
    end

    def coerce_multiplicity m
    result = \
      case m
      when nil
        1..1
      when Range
        m
      when Integer
        m .. m
      when :*, '*'
        0..UNLIMITED
      when String
        a, b = m.split('..')
        a = coerce_multiplicity_value(a)
        b = coerce_multiplicity_value(b)
        a..b
      else
        raise ArgumentError, "given #{m.inspect}"
      end
      # $stderr.puts "  ### coerce_multiplicity #{m.inspect} => #{result.inspect}"
      result
    end

    META_TO_MODULE_CLASS = {
      Package: "module",
      Namespace: "module",
      Class: "class",
      Root: nil,
    }.freeze

    LAMBDA_NIL = proc { nil } unless defined? LAMBDA_NIL

    def hasStereotype? node, name
      name = name.to_s
      node.stereotype&.find{|x| x.name == name}
    end

    def find_node_scoped(node, name)
      return name unless ::String === name
      navigator.find_node_scoped(node, name)
    end

    def namespace_str(node)
      navigator.namespace_str(node)
    end

    def fix_name name
      KEYWORDS.include?(name) ? "#{name}_" : name
    end

    KEYWORDS = %w[
      if then else end begin
      case when
      try catch raise
      class module
    ].freeze
  end
end # module
