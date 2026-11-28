# frozen_string_literal: true

require 'ruml/compiler/target'
require 'ruml/support/initialize'
require 'ruml/support/misc'
require 'ruml/core/runtime'
require 'ruml/core/primitive_types'
require 'method_source'
require 'ripper'
require 'pp'

module RUML::Compiler
  # !!! change this to an ERB template
  # this class can provide helpers, 
  # access to introspection,
  # traversal state.
  # templates can emit comments to redirect
  # sections to different files and/or blocks.
  # the methods below are candidates for helper.
  # however, these helpers might create data structures.
  # perhaps, they can inject bindings into the caller.
  class Target::Ruby < Target
    UNLIMITED = 12345678901234567890
    STAR = UNLIMITED

    PrimitiveTypes = RUML::Core::PrimitiveTypes

    include RUML::Support::Misc

    # !!! needs an output_dir atrr opt.
    def default_code_file(root)
      basename = root.to_s.gsub(/::/, '-').downcase
      f"tmp/#{basename}.rb"
    end

    # !!! this should be a template:
    def emit_preamble(node)
      line! "# frozen_string_literal: true"
      line!
      comment_begin! "GENERATED"
      trace! '"BEGIN"'
      line! "require 'ruml/core/runtime'"
      line! "require 'ruml/core/primitive_types'"
      line! "require 'ruml/core/misc'"
      # line! "require 'pry'"
      # line! "binding.pry"
      line!
    end

    def emit_postamble(node)
      trace! '"END"'
      comment_end! "GENERATED"
      # line! "binding.pry"
      line!
    end

    
    # !!! use introspection on Native objs
    def emit_root(node)
      # !!! this should be a helper function.
      @root_node = root_node
      @root_path = navigator.path_str(@root_path)
      ns = frontend.root
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
      return if navigator.isPrimitiveType?(node) || navigator.isNativeModule?(node)

      path = navigator.namespace_path(node)
      path_str = navigator.path_str(node)
      kind = META_TO_MODULE_CLASS.fetch(node._.metatype)
      desc = "#{kind} #{path_str}"
      declaration = desc.dup
      raise if path_str =~ /PrimitiveTypes/

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

      is_class = navigator.isClass?(node)
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

      comment_begin! desc
      node.stereotype&.each do | st |
        comment! "stereotype <<#{st.name}>>"
      end
      line! declaration

      line! "  include ::RUML::Core::Runtime::BaseClass"
      line! "  ruml.loading(__FILE__, __LINE__)"
      data = namespace_native_data(node)
      line! "  ruml.native_data = \n#{PP.pp(data, +"")}"

      if is_class
        import_method = nil # "inherited"
      else
        import_method = "included"
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
      if import_method
        line! "  def self.#{import_method}(target)"
        # trace! "\"import : \#{self}.#{import_method}(\#{target})\""
        line! "    # super(target)"
        line! "    self.include(target::RUML_InstanceBehavior)"
        line! "    self.extend(target::RUML_ModuleBehavior)"
        line! "  end"
      end
      line! "  self"
      line! "end # #{desc}"
      line! ""
      comment_end! desc
    end

    def namespace_native_data node
      node.ownedAttribute ||= []
      ownedAttribute = node.ownedAttribute.sort_by(&:name).map{|x| attribute_native_data(x)}
      {
        name:           node.name,
        qualifiedName:  navigator.path_str(node),
        ownedAttribute: ownedAttribute,
      }
    end

    def attribute_native_data node
      opposite = node.opposite && {
        owner: navigator.path_str(node.opposite.owner),
        name: node.opposite.name.to_sym,
      }
      {
        owner: navigator.path_str(node.owner),
        name: node.name.to_sym,
        type: node.type.to_s,
        lower: node.lower,
        upper: node.upper,
        default: node.default,
        isAssociation: !! node.owningAssociation,
        opposite: opposite,
      }
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
      line! "$stderr.puts(\"##RUML TRACE : \#{__FILE__}:\#{__LINE__} : \" + (#{expr}).to_s)"
      # comment_end! "TRACE"
    end

    def emit_PackageImport node
      dst_path = navigator.path_str(node.importingNamespace)
      src_path = navigator.path_str(node.importedPackage)
      line! "  ::RUML::Core::Runtime::Import.import_package(::#{dst_path}, ::#{src_path})"
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

      desc = "Generalization : #{node_path}"
      # comment_begin! desc
      # line!

      if false
        comment! "Instantiable #######################"
        line! "  #{node_path}.include(#{instantiation_module(node)})"
        line!
      end

      node._.superClass_remaining&.each do | gen |
        gen_path = navigator.path_str(find_node_scoped(parent, gen))
        comment! "#{desc} : superClass #{node_path} -> #{gen_path}"
        emit_gen(node_path, :include, gen)
        line!
      end

      generals.each do | gen |
        gen_path = navigator.path_str(gen)
        comment! "#{desc} : #{node_path} -> #{gen_path}"
        emit_gen(node_path, :include, gen)
        line!
      end
      # comment_end! desc
    end

    def emit_gen(node_path, op, gen)
      gen_path = navigator.path_str(gen)
      native_mod = navigator.native_module(gen)
      if native_mod
        if ::Module === native_mods && op == :include
          subpath = nil
        else
          comment! ": skipping #{op} #{gen_path}"
          gen_path = nil
        end
      else
        subpath = op == :include ? "::RUML_InstanceBehavior" : "::RUML_ModuleBehavior"
      end
      line! "  #{node_path}.#{op}(#{gen_path}#{subpath})" if gen_path
    end

    def emit_operation(node)
      name = node.name.to_sym
      body = node._.body
      # Unset blk to avoid serialization issue.
      blk = node._.blk
      node._.blk = nil
      body ||= extract_method_body(blk.source.to_s)
      line! <<"RUBY"
def #{name}
  #{body}
end
RUBY
    end

    def isOperation?(node)
      node._.body || node._.blk
    end

    # !!! put this in Boot::Buildet?
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
        emit_association(node)
      else
        emit_property(node)
      end
    end

    def emit_property node, opts = {}
      
      node_path = namespace_str(node.class)
      node_type = node.type
      node_type = node_type[0] if ::Array === node_type # !!!
      # !!! delete
      binding.pry unless find_node_scoped(node.class, node_type)
      node_type = find_node_scoped(node.class, node_type)
      type_name = navigator.native_path_or(node_type)
      primitive = navigator.isPrimitiveType?(node_type)
      enumeration = navigator.hasStereotype?(node_type, :enumeration)

      # !!! delete
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

      typecheck_msg = "expected #{type} : given \#{__val.class}"

      if primitive || enumeration
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
raise ::ArgumentError, "#{msg} : #{desc} : #{typecheck_msg}" unless __val.nil? || #{type} === __val
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
      e = node.opposite or raise
      o = node or raise
      # binding.pry
      upper = o.upper
      upper = :* if upper < 0
      e_type = namespace_str(e.type)
      o_type = namespace_str(o.type)
      desc_short = "#{e_type}::#{o.name}"
      desc = "Association : #{desc_short} : #{e_type} #{o.lower}..#{upper}"
      o_name = fix_name(o.name)
      e_name = fix_name(e.name)
      subsets = o.subsets.map{|s| path_str_base(s) }
      args = [desc_short, o_name, o_type, o.lower, upper, subsets, e_name, e_type ]
      comment_begin! desc
      if upper == 1
        emit_association_1(*args)
      else
        emit_association_N(*args)
      end
      comment_end! desc
    end

    def emit_association_1 desc, name, type, lower, upper, subsets, ename, etype
      typecheck_msg = "expected #{type} : given \#{__val.class}"
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
    raise ArgumentError, "#{name}= : #{desc} : #{typecheck_msg}" unless __val.nil? || #{type} === __val
    #{name}_clear!
    #{name}_add!(__val)
  end
  def #{name}_clear!
    #{name}_remove!(@#{name})
  end
  def #{name}_add!(__val)
    return self if __val.nil?
    unless __val == @#{name}
      raise ArgumentError, "#{name}_add! : #{desc} : already set" unless @#{name}.nil?
      @#{name} = __val
      #{generate_subsets(subsets, "_add!")}
      __val.#{ename}_add!(self)
    end
    self
  end
  def #{name}_remove!(__val)
    return self if __val.nil?
    if __val == @#{name}
      raise ArgumentError, "#{name}_remove! : #{desc} :  #{typecheck_msg}" unless #{type} === __val
      @#{name} = nil
      #{generate_subsets(subsets, "_remove!")}
      __val.#{ename}_remove!(self)
    end
    self
  end
RUBY
    end

    def emit_association_N desc, name, type, lower, upper, subsets, ename, etype
      typecheck_msg = "expected #{type} : given \#{__val.class}"
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
    raise ArgumentError, "#{name}_add! : #{desc} : #{typecheck_msg}" unless #{type} === __val
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
    raise ArgumentError, "#{name}_remove! : #{desc} : #{typecheck_msg}" unless #{type} === __val
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
        "##RUML subsets #{subset}\n      #{subset}#{suffix}(__val)"
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

    def find_node_scoped(node, name)
      return name unless ::String === name
      navigator.find_node_scoped(node, name)
    end

    def namespace_str(node)
      navigator.path_str(node)
    end

    def keywords
      @keywords ||= %w[
        if then else end begin
        case when
        try catch raise
        class module
      ].freeze
    end
  end
end # module
