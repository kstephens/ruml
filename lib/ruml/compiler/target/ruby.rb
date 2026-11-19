# frozen_string_literal: true

require 'ruml/compiler/target'
require 'ruml/support/initialize'
require 'method_source'
require 'ripper'

module RUML::Compiler
  class Target::Ruby < Target
    UNLIMITED = 12345678901234567890
    STAR = UNLIMITED

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

      if node._.meta == :class
        supers = node.superClass.map{|super_| navigator.find_node_scoped(node.namespace, super_)}
        if (super_ = supers.shift)
          super_path_str = navigator.path_str(super_)
          binding.pry if super_path_str.nil? || super_path_str.empty?
          declaration << " < #{super_path_str}"
        end
        node._.superClass_remaining = supers
      end

      lines = []
      lines << declaration
      lines << "  module RUML_InstanceBehavior"
      lines << "  end"
      lines << "  module RUML_ModuleBehavior"
      lines << "  end"
      lines << "  def self.included(target)"
      lines << "    target.include(RUML_InstanceBehavior)"
      lines << "    target.extend(RUML_ModuleBehavior)"
      lines << "  end"
      node._.ruby_include&.each do | m |
        lines << "  include #{m}"
      end
      node._.ruby_extend&.each do | m |
        lines << "  extend #{m}"
      end
      lines << "  self"
      lines << "end"
      lines << ""
      self << lines
    end

    def emit_import node
      parent = node.namespace
      dst = navigator.namespace_str(node)
      lines = []
      node.args.flatten.each do | name |
        src = navigator.namespace_path(navigator.find_node_scoped(parent, name))
        lines << "#{src}.constants do | n |"
        lines << "  #{dst}.const_set(n, #{src}.const_get(n))"
        lines << "end"
      end
      self << lines
    end

    def emit_generalization node
      node_path = navigator.path_str(node)
      parent = node.namespace
      generals = (node.generalization || []).map(&:general)
      generals.map! do |g|
        path = navigator.convert_to_name_path(g)
        node = navigator.find_node(parent, path)
        navigator.path_str(node)
      end

      lines = []
      if node._.isAbstract
        lines << "#{node_path}.include(::RUML::Core::Runtime::Uninstantiatable)"
      else
        lines << "#{node_path}.include(::RUML::Core::Runtime::Instantiable)"
      end
      node._.superClass_remaining.each do | super_ |
        gen_path = navigator.path_str(navigator.find(parent, super_))
        lines << "#{node_path}.include(#{gen_path}::RUML_InstanceBehavior)"
      end
      generals.each do | gen_path |
        lines << "#{node_path}.include(#{gen_path}::RUML_InstanceBehavior)"
      end
      lines << "#{node_path}.include(#{node_path}::RUML_InstanceBehavior)"
      lines << "#{node_path}.extend(#{node_path}::RUML_ModuleBehavior)"
      self << lines
    end

    def emit_operation(node)
      name = node.name.to_sym
      body = node.body
      if ! body && node._.blk
        body = extract_method_body(node._.blk.source.to_s)
      end
      self << "module " << path_module(node) << "\n"
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
      lines = []
      lines << "module " << path_module(node)
      if method
          lines << <<"RUBY"
        def self.#{node.name} ; #{name_upper} ; end
        def #{node.name} : #{name_upper} ; end
RUBY
        end
      self << <<"RUBY"
#{name_upper} = #{value}
RUBY
      lines << "end"
      self << lines
    end

    def emit_property node
      # opts = node._.opts ||= {}
      name = node.name
      type = navigator.path_str(node.type)
      multiplicity = coerce_multiplicity(node.multiplicity)
      opts = {primitive: hasStereotype?(node.type, :primitive)}
      node._.resolved_type = type
      node._.multiplicity = multiplicity
      self << "module " << path_module(node) << "\n"
      self << generate_property(name, type, multiplicity, opts)
      self << "end\n"
    end

    def generate_property node, opts
      name, type, lower, upper, default =
        node.name, node.type, node.lower, node.upper, node.default

      desc = "Property : #{node.owner}.#{name} : #{type} #{lower}..#{upper < 0 ? "*" : upper}"
      desc << " = #{default}" unless default.nil?

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
raise ::ArgumentError, "#{msg}: expected #{type}" unless __val.nil? || #{type} === __val
RUBY
        }
      end

      typecheck_min = if lower == 1
        lambda { | msg |
          <<"RUBY"
raise ::ArgumentError, #{desc.inspect} if __val.nil?
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
      binding.pry if result.nil? || result.empty?
      result
    end
    def _path_module(node)
      parent = node.namespace
      node._.isStatic ? parent._.ruby_module_behavior : parent._.ruby_instance_behavior
    end

    def emit_association(
      name1, type1, multiplicity1, opts1,
      name2, type2, multiplicity2, opts2
    )
=begin
      $stderr.puts \
"  # association #{name1.inspect}, #{type1.inspect}, #{multiplicity1.inspect}, #{opts1.inspect},
                 #{name2.inspect}, #{type2.inspect}, #{multiplicity2.inspect}, #{opts2.inspect}"
=end
      opts1 ||= EMPTY_Hash
      opts2 ||= EMPTY_Hash
      type1 ||= self
      type2 or raise ArgumentError
      name1 ||=
        begin
          x = type1.to_s
          x.sub!(/.*::/, '')
          x[0 .. 0].downcase + x[1 .. -1]
        end
      multiplicity1 ||= (1 .. 1)
      multiplicity1 = _coerce_multiplicity multiplicity1
      name1 = name1.to_s
      name1 = "_#{name1}" if name1 == 'class'

      name2 ||=
        begin
          x = type2.to_s
          x.sub!(/.*::/, '')
          x[0 .. 1].downcase + x[1 .. -1]
        end
      multiplicity2 ||= (1 .. 1)
      multiplicity2 = _coerce_multiplicity multiplicity2
      opts2 ||= EMPTY_Hash
      name2 = name2.to_s
      name2 = "_#{name2}" if name2 == 'class'

=begin
      $stderr.puts \
"  # _association #{name1.inspect}, #{type1.inspect}, #{multiplicity1.inspect}, #{opts1.inspect},
                 #{name2.inspect}, #{type2.inspect}, #{multiplicity2.inspect}, #{opts2.inspect}"
=end

      end1 = { :name => name1.to_sym, :type => type1, :lower => multiplicity1.first, :upper => multiplicity1.last }.update(opts1)
      end2 = { :name => name2.to_sym, :type => type2, :lower => multiplicity2.first, :upper => multiplicity2.last }.update(opts2)

      generate_association(end1, end2)
    end

    def generate_association end1, end2
      [ [ :end1, end1, end2 ], [ :end2, end2, end1 ] ].map do | (side, e, o) |
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
        {
          side: side,
          code: code,
          end1: end1,
          end2: end2,
        }
      end
    end

    def generate_association_1 name, type, lower, upper, subsets, ename, etype
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
      package: "module",
      namespace: "module",
      class: "class",
      root: nil,
    }.freeze


    LAMBDA_NIL = proc { nil } unless defined? LAMBDA_NIL

    def hasStereotype? node, name
      name = name.to_s
      node.stereotype&.find{|x| x.name == name}
    end

  end # module
end # module
