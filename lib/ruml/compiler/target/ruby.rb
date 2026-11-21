# frozen_string_literal: true

require 'ruml/compiler/target'
require 'ruml/support/initialize'
require 'ruml/support/misc'
require 'ruml/core/runtime'
require 'method_source'
require 'ripper'

module RUML::Compiler
  class Target::Ruby < Target
    UNLIMITED = 12345678901234567890
    STAR = UNLIMITED

    include RUML::Support::Misc

    def emit_preamble(node)
      line! "# frozen_string_literal: true"
      line!
      comment_begin! "GENERATED"
      line! "require 'ruml/core/runtime'"
      line! "require 'ruml/core/misc'"
      # line! "require 'pry'"
      # line! "binding.pry"
      line!
    end

    def emit_postamble(node)
      comment_end! "GENERATED"
      line!
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

      is_class = isClass?(node)
      if is_class
        supers = (node.superClass || []).map do |name|
          or_die(find_node_scoped(node.namespace, name)) do
            "class #{node.name} : cannot find superclass #{name.inspect}"
          end
        end
        if (super_ = supers.shift)
          super_path_str = navigator.path_str(super_)
          declaration << " < #{super_path_str}"
          # trace! "\"#{declaration} : \#{#{super_path_str}.class} \#{#{super_path_str}}\""
        end
        node._.superClass_remaining = supers
      end

      desc = "#{node._.meta} #{node.name}"
      comment_begin! desc
      node.stereotype&.each do | st |
        comment! "stereotype <<#{st.name}>>"
      end
      line! declaration

      if is_class
        import_method = nil # "inherited"
      else
        import_method = "included"
      end
      if import_method
        line! "  def self.#{import_method}(target)"
        # trace! "\"import : \#{self}.#{import_method}(\#{target})\""
        line! "    # super(target)"
        line! "    self.include(target::RUML_InstanceBehavior)"
        line! "    self.extend(target::RUML_ModuleBehavior)"
        line! "  end"
      end

      line! "  module RUML_InstanceBehavior"
      node.ownedAttribute&.each do | prop |
        emit_attribute(prop)
      end
      line! "  end"
      line! "  module RUML_ModuleBehavior"
      line! "  end"
      emit_enumeration(node)
      line! "  self.include(RUML_InstanceBehavior)"
      line! "  self.extend(RUML_ModuleBehavior)"
      line! "  self.include(#{instantiation_module(node)})"
      node._.ruby_include&.each do | m |
        line! "  self.include #{m}"
      end
      node._.ruby_extend&.each do | m |
        line! "  self.extend #{m}"
      end
      line! "  self"
      line! "end"
      line! ""
      comment_end! desc
    end

    def instantiation_module node
      if node.isAbstract
        "::RUML::Core::Runtime::Uninstantiatable"
      else
        "::RUML::Core::Runtime::Instantiable"
      end
    end

    def trace! expr
      # comment_begin! "TRACE"
      line! "$stderr.puts('##RUML TRACE : ' + (#{expr}).to_s)"
      # comment_end! "TRACE"
    end

    def emit_import node
      dst_path = module_path(node)
      node.importedPackage&.each do | src |
        # binding.pry
        src_path = module_path(src)
        line! "::RUML::Core::Runtime::Import.import(::#{dst_path}, ::#{src_path})"
      end
    end

    def emit_enumeration node
      names = (node.ownedLiteral || []).map(&:name)
      return "" if names.empty?
      line!
      line! "  self.include(::RUML::Core::Runtime::Enumeration)"
      line! "  def self.enumeration_names"
      line! "    @__enumeration_names__ ||= #{names.inspect}.map!(&:freeze).freeze"
      line! "  end"
      line!
    end

    def emit_generalization node
      node_path = navigator.path_str(node)
      parent = node.namespace
      generals = (node.generalization || []).map(&:general)
      generals.map! do |gen|
        find_node_scoped(parent, gen)
      end

      desc = "Generalization"
      comment_begin! desc
      line!

      if false
        comment! "Instantiable #######################"
        line! "  #{node_path}.include(#{instantiation_module(node)})"
        line!
      end

      comment! "Superclass #######################"
      node._.superClass_remaining&.each do | gen |
        gen_path = navigator.path_str(find_node_scoped(parent, gen))
        comment! "superClass #{node_path} -> #{gen_path}"
        emit_gen(node_path, :include, gen)
        line!
      end

      comment! "Generals #######################"
      generals.each do | gen |
        emit_gen(node_path, :include, gen)
        line!
      end
      comment_end! desc
    end

    def emit_gen(node_path, op, gen)
      gen_path = navigator.path_str(gen)
      subpath = nil
      comment! "Generalization #{node_path} -> #{gen_path}"
      if gen._.native
        if gen._.kind == "module"
          line! "#{node_path}.include(#{gen_path}"
        else
          comment! ": skipping #{gen_path}"
          gen_path = nil
        end
      else
        subpath = op == :include ? "::RUML_InstanceBehavior" : "::RUML_ModuleBehavior"
      end
      line! "#{node_path}.#{op}(#{gen_path}#{subpath})" if gen_path
    end

    def emit_operation(node)
      name = node.name.to_sym
      body = node._.body
      if ! body && node._.blk
        body = extract_method_body(node._.blk.source.to_s)
      end
      line! <<"RUBY"
def #{name}
  #{body}
end
RUBY
    end

    def isOperation?(node)
      node._.body || node._.blk
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

    def emit_attribute node, opts = {}
      if node.isDerived && isOperation?(node)
        emit_operation(node)
      elsif node.owningAssociation
        binding.pry unless node.opposite
        emit_association(node)
      else
        emit_property(node)
      end
    end

    def emit_property node, opts = {}
      node_path = namespace_str(node.class)
      node_type = node.type
      node_type = node_type[0] if ::Array === node_type # !!!
      type_name = namespace_str(node_type)
      primitive = isPrimitiveType?(node_type)
      # binding.pry if primitive
      opts = {primitive: primitive}.merge(opts)
      primitive = opts[:primitive]
      name, type, lower, upper, default =
        node.name, type_name, node.lower, node.upper, node.default

      desc = "Property : #{node_path}::#{name} : #{type} #{lower}..#{upper < 0 ? "*" : upper}"
      desc << " = #{default}" unless default.nil?

      # $stderr.puts "#emit_property: type_name=#{type_name} #{primitive}"
      name = fix_name(name)

      comment_begin! desc
      # binding.pry if opts[:primitive]

      if primitive
        coerce = lambda { | _msg |
          <<"RUBY"
__val = #{type}.__ruml_coerce__(__val) unless __val.nil?
RUBY
        }
        typecheck = LAMBDA_NIL
      else
        coerce = LAMBDA_NIL
        typecheck = lambda { | msg |
          <<"RUBY"
raise ::ArgumentError, "#{msg} : #{desc} : expected #{type}" unless __val.nil? || #{type} === __val
RUBY
        }
      end

      typecheck_min = if lower == 1
        lambda { | msg |
          <<"RUBY"
raise ::ArgumentError, "#{msg} : #{desc} : expected non-nil value" if __val.nil?
RUBY
        }
      else
        LAMBDA_NIL
      end

      multiplicity_min = if lower > 0
        lambda { | msg, size |
          <<"RUBY"
raise ::ArgumentError, "#{msg} : #{desc} : expected min size #{size}" unless #{size} >= #{lower}
RUBY
          }
      else
        LAMBDA_NIL
      end

      multiplicity_max = unless upper < 0 || upper == UNLIMITED
        lambda { | msg, size |
          <<"RUBY"
raise ::ArgumentError, "#{msg} : #{desc} : expected max size #{size}" unless #{size} <= #{upper}
RUBY
          }
      else
        LAMBDA_NIL
      end

      typecheck = LAMBDA_NIL unless type

      default = "||= #{default.inspect}" unless default.nil?

      case upper
      when 1
        self << <<"RUBY"
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
        self << <<"RUBY"
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
      comment_end! desc
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
      # binding.pry
      upper = o.upper
      upper = :* if upper < 0
      e_type = namespace_str(e.type)
      o_type = namespace_str(e.type)
      desc_short = "#{e_type}::#{o.name}"
      desc = "Association : #{desc_short} : #{o_type} #{o.lower}..#{upper}"
      o_name = fix_name(o.name)
      e_name = fix_name(e.name)
      args = [desc_short, o_name, o_type, o.lower, upper, o.subsets, e_name, e_type ]
      comment_begin! desc
      if upper == 1
        emit_association_1(*args)
      else
        emit_association_N(*args)
      end
      comment_end! desc
    end

    def emit_association_1 desc, name, type, lower, upper, subsets, ename, etype
      self << <<"RUBY"
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
    raise ArgumentError, "#{desc} : #{name}= : expected #{type}" unless __val.nil? || #{type} === __val
    #{name}_clear!
    #{name}_add!(__val)
  end
  def #{name}_clear!
    #{name}_remove!(@#{name})
  end
  def #{name}_add!(__val)
    return self if __val.nil?
    unless __val == @#{name}
      raise ArgumentError, "#{desc} : #{name}_add!: already set" unless @#{name}.nil?
      @#{name} = __val
      #{generate_subsets(subsets, "_add!")}
      __val.#{ename}_add!(self)
    end
    self
  end
  def #{name}_remove!(__val)
    return self if __val.nil?
    if __val == @#{name}
      raise ArgumentError, "#{desc} : #{name}_remove!: expected #{type}" unless #{type} === __val
      @#{name} = nil
      #{generate_subsets(subsets, "_remove!")}
      __val.#{ename}_remove!(self)
    end
    self
  end
RUBY
    end

    def emit_association_N desc, name, type, lower, upper, subsets, ename, etype
      self << <<"RUBY"
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
    raise ArgumentError, "#{desc} : #{name}_add!: expected #{type}" unless #{type} === __val
    __cur = #{name}
    unless __cur.include?(__val)
      __cur.push(__val)
      #{generate_subsets(subsets, "_add!")}
      __val.#{ename}_add!(self)
    end
    self
  end
  def #{name}_remove! __val
    return self if _val.nil?
    raise ArgumentError, "#{desc} : #{name}_remove!: expected #{type}" unless #{type} === __val
    __cur = #{name}
    if __cur.include?(__val)
      __cur.delete(__val)
      #{generate_subsets(subsets, "_remove!")}
      __val.#{ename}_remove!(self)
    end
    self
  end
RUBY
    end

    def generate_subsets subsets, suffix
      subsets.map do |subset|
        "##RUML subsets #{subset}\n#{subset}#{suffix}(__val)\n"
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

    def isClass? node
      node._.meta == :Class
    end

    def isPrimitiveType? type
      result = false
      native = native_type(type)
      result ||= native && native.ancestors.include?(RUML::Core::PrimitiveType)
      result ||= hasStereotype?(type, :primitive)
      # result ||= namespace_str(type_name) =~ /\ARUML::Core::PrimitiveTypes::/
      result
    end

    def hasStereotype? node, name
      name = name.to_s
      binding.pry if node.stereotype && node.stereotype.size > 0
      node.stereotype&.find{|x| x.name == name}
    end

    def native_type type
      type.__ruml_obj__ if RUML::Compiler::Native::RNamespace === type
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
