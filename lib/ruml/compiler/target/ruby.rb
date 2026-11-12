# frozen_string_literal: true

require 'ruml/compiler/target'
require 'ruml/support/initialize'
require 'method_source'
require 'ripper'

module RUML::Compiler
  class Target::Ruby < Target
    UNLIMITED = 12345678901234567890
    STAR = UNLIMITED

    def emit_namespace(node)
      path = node._.namespace_path
      node_path_str = path.map(&:name).compact.join("::")
      full_path_str = node._.root_package.to_s + "::" + node_path_str
      kind = META_TO_MODULE_CLASS.fetch(node._.meta)
      declaration = "#{kind} #{full_path_str}"

      node._.to_h.update(
        path: path,
        node_path_str: node_path_str,
        full_path_str: full_path_str,
        full_path_instance_behavior: "#{full_path_str}::RUML_InstanceBehavior",
        full_path_module_behavior: "#{full_path_str}::RUML_ModuleBehavior",
        ruby_module_kind: kind,
        ruby_declaration: declaration,
        ruby_declaration_full: "#{kind} #{full_path_str}",
      )
      log { "#{full_path_str} { " }

      if node._.meta == :class
        supers = node.superClass.map{|super_| node.namespace._.lookup_node(super_)}
        if (super_ = supers.shift)
          declaration << " < #{super_._.full_path_str}"
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
      dst = node._.full_path_str
      lines = []
      node.args.flatten.each do | name |
        src = parent._.lookup_node(name)._.full_path_str
        lines << "#{src}.constants do | n |"
        lines << "  #{dst}.const_set(n, #{src}.const_get(n))"
        lines << "end"
      end
      self << lines
    end

    def emit_generalization node
      node_path = node._.full_path_str
      parent = node.namespace
      generals = (node.generalization || []).map(&:general)
      generals.map!{|g| parent._._find(g)._.full_path_str}

      lines = []
      if node._.isAbstract
        lines << "#{node_path}.include(::RUML::Core::Runtime::Uninstantiatable)"
      else
        lines << "#{node_path}.include(::RUML::Core::Runtime::Instantiable)"
      end
      node._.superClass_remaining.each do | super_ |
        gen_path = parent._.find(super_)._.full_path_str
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
      self << "module " << full_path_module(node) << "\n"
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
      lines << "module " << full_path_module(node)
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
      type = node.type._.full_path_str
      multiplicity = coerce_multiplicity(node.multiplicity)

      if hasStereotype?(node.type, :primitive)
        coerce = lambda { | _msg |
          <<"RUBY"
__val = __val.nil? ? __val : ::#{type}.coerce(__val)
RUBY
        }
        typecheck = LAMBDA_NIL
      else
        coerce = LAMBDA_NIL
        typecheck = lambda { | msg |
          <<"RUBY"
raise ::ArgumentError, "#{msg}: expected #{type}" unless __val.nil? || ::#{type} === __val
RUBY
        }
      end

      typecheck_min = if multiplicity.first == 1
        lambda { | msg |
          <<"RUBY"
raise ::ArgumentError, "#{msg}: #{type} [#{multiplicity}]" if __val.nil?
RUBY
        }
      else
        LAMBDA_NIL
      end

      multiplicity_min = if multiplicity.first > 0
        lambda { | msg, size |
          <<"RUBY"
raise ::ArgumentError, "#{msg}: #{type} [#{multiplicity}]" unless #{size} >= #{multiplicity.first}
RUBY
          }
      else
        LAMBDA_NIL
      end

      multiplicity_max = if multiplicity.last != UNLIMITED
        lambda { | msg, size |
          <<"RUBY"
raise ::ArgumentError, "#{msg}: #{type} [#{multiplicity}]" unless #{size} <= #{multiplicity.last}
RUBY
          }
      else
        LAMBDA_NIL
      end

      code = "# Property #{name} : #{type} #{node.multiplicity}\n"
      case multiplicity.last
      when 1
        code << <<"RUBY"
  def #{name}
    @#{name}
  end
  def #{name}_count
    @#{name}.nil? ? 0 : 1
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
      #{multiplicity_max.call("add_#{name}!", "count_#{name} + 1")}
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
      #{multiplicity_min.call("#{name}=", "#{name}_count - 1")}
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
  def #{name}_count
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
      node._.resolved_type = type
      node._.multiplicity = multiplicity
      self << "module " << full_path_module(node) << "\n"
      self << code
      self << "end\n"
    end


    def full_path_module(node)
      parent = node.namespace
      node._.isStatic ? parent._.full_path_module_behavior : parent._.full_path_instance_behavior
    end

    def generate_association \
      name1, type1, multiplicity1, opts1,
      name2, type2, multiplicity2, opts2 = nil
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

      end1 = { :name => name1.to_sym, :type => type1, :multiplicity => multiplicity1 }.update(opts1)
      end2 = { :name => name2.to_sym, :type => type2, :multiplicity => multiplicity2 }.update(opts2)

      result = []

      [ [ :end_1, end1, end2 ], [ :end_2, end2, end1 ] ].each do | (side, e, o) |
        ename = e[:name]
        etype = e[:type]

        name = o[:name]
        type = o[:type]
        multiplicity = o[:multiplicity]

        subsets = o[:subsets]
        subsets = [ subsets ] unless Array === subsets
        subsets = subsets.compact

        case multiplicity.end
        when 1
          code = _generate_association_1(name, type, multiplicity, subsets, ename, etype)
        else
          code = _generate_association_N(name, type, multiplicity, subsets, ename, etype)
        end

        result[side] = {
          meta: {
            side: side,
            code: code,
          },
          node: {
            name: name,
            type: type,
            multiplicity: multiplicity,
            subsets: subsets,
          }
        }
      end

      result
    end

    def generate_association_1 name, type, multiplicity, subsets, ename, etype
      code = <<"RUBY"
  # AssociationEnd #{name} : #{type} #{multiplicity}
  def #{name}
    @#{name}
  end
  def count_#{name}
    @#{name} ? 1 : 0
  end
  def multi_#{name}
    @#{name} ? [ @#{name} ] : [ ]
  end
  def #{name}= __val
    raise ArgumentError, "#{name}: expected #{type}" unless __val.nil? || #{type} === __val
    clear_#{name}!
    add_#{name}! __val
  end
  def clear_#{name}!
    remove_#{name}! @#{name}
  end
  def add_#{name}! __val
    return self if __val.nil?
    unless @#{name} == __val
      raise ArgumentError, "add_#{name}!: already set" unless @#{name}.nil?
      @#{name} = __val
      #{subsets.map{|s| "add_#{s}!(__val)"} * '; '} # subsets #{subsets * ', '}
      __val.add_#{ename}!(self)
    end
    self
  end
  def remove_#{name}! __val
    return self if __val.nil?
    if @#{name} == __val
      raise ArgumentError, "remove_#{name}!: expected #{type}" unless #{type} === __val
      @#{name} = nil
      #{subsets.map{|s| "remove_#{s}!(__val)"} * '; '} # subsets #{subsets * ', '}
      __val.remove_#{ename}!(self)
    end
    self
  end
RUBY
      code
    end

    def generate_association_N name, type, multiplicity, subsets, ename, etype
      code = <<"RUBY"
  # AssociationEnd #{name} : #{type} #{multiplicity}
  def #{name}
    @#{name} ||= [ ]
  end
  def count_#{name}
    #{name}.size
  end
  alias :multi_#{name} :#{name}
  def #{name}= __vals
    clear_#{name}!
    __vals.each { | __val | add_#{name}! __val }
    self
  end
  def clear_#{name}!
    #{name}.dup.each { | __val | remove_#{name}! __val }
    self
  end
  def add_#{name}! __val
    return self if __val.nil?
    raise ArgumentError, "add_#{name}!: expected #{type}" unless #{type} === __val
    __cur = #{name}
    unless __cur.include?(__val)
      __cur.push(__val)
      #{subsets.map{|s| "add_#{s}!(__val)"} * '; '} # subsets #{subsets * ', '}
      __val.add_#{ename}!(self)
    end
    self
  end
  def remove_#{name}! __val
    return self if __val.nil?
    raise ArgumentError, "remove_#{name}!: expected #{type}" unless #{type} === __val
    __cur = #{name}
    if __cur.include?(__val)
      __cur.delete(__val)
      #{subsets.map{|s| "remove_#{s}!(__val)"} * '; '} # subsets #{subsets * ', '}
      __val.remove_#{ename}(self)
    end
    self
  end
RUBY
      code
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
