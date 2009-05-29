
module RUML

module Support
  EMPTY_HASH = { }.freeze unless defined? EMPTY_HASH
  N = 1000000000000000 unless defined? N
  STAR = 0 .. N unless defined? STAR

  module CodeGenerationCore
    def _class_eval cls, str, file, line
      $stderr.puts "\nclass #{cls}\n#{str}\nend\n\n"
      cls.class_eval str, file, line
    end
    
    def _coerce_multiplicity m
      result =
      case m
      when Range
        m
      when Integer
        m .. m
      when :*, '*'
        STAR
      when String
        eval(m)
      else
        raise ArgumentError, "given #{m.inspect}"
      end
      # $stderr.puts "  # _coerce_multiplicity #{m.inspect} => #{result.inspect}"
      result
    end


    def _generate_property cls, name, type, mutiplicity = nil, opts = nil
      multiplicity ||= 1 .. 1
      multiplicity = _coerce_multiplicity multiplicity
      opts ||= EMPTY_HASH

      if type.hasStereotype?(:primitive)
        typecheck = lambda { | msg | 
          <<"RUBY"
__val = #{type}.coerce(__val)
RUBY
        }
      else
        typecheck = lambda { | msg | 
          <<"RUBY"
raise ArgumentError, "#{msg}: expected #{type}" unless #{type} === __val
RUBY
        }
      end

      case multiplicity.end
      when 1
        _class_eval cls, <<"RUBY", __FILE__, __LINE__
  # Property #{name} : #{type} #{multiplicity}
  def #{name}
    @#{name}
  end
  def #{name}= __val
    #{typecheck.call("#{name}=")}
    clear_#{name}!
    @#{name} = __val
  end
  def clear_#{name}!
    @#{name} = nil
  end
  def add_#{name}! __val
    return self if __val.nil?
    #{typecheck.call("add_#{name}!")}
    raise ArgumentError, "add_#{name}!: already set" unless @#{name}.nil?
    @#{name} = __val
    self
  end
  def remove_#{name}! __val
    return self if __val.nil?
    #{typecheck.call("remove_#{name}!")}
    @#{name} = nil if @#{name} == __val
    self
  end
RUBY
      else
        _class_eval cls, <<"RUBY", __FILE__, __LINE__
  # Property #{name} : #{type} #{multiplicity}
  def #{name}
    @#{name} ||= [ ]
  end
  def #{name}= __vals
    clear_#{name}!
    __vals.each { | __val | add_#{name}! __val }
  end
  def clear_#{name}!
    #{name}.clear
    self
  end
  def add_#{name}! __val
    return self if __val.nil?
    #{typecheck.call("add_#{name}!")}
    #{name}.push(__val)
    self
  end
  def remove_#{name} __val
    return self if __val.nil?
    #{typecheck.call("remove_#{name}!")}
    #{name}.delete(__val)
    self
  end
RUBY
      end
    end


    def _generate_association name1, type1, multiplicity1, opts1,
                     name2, type2, multiplicity2, opts2 = nil
=begin
      $stderr.puts \
"  # association #{name1.inspect}, #{type1.inspect}, #{multiplicity1.inspect}, #{opts1.inspect},
                 #{name2.inspect}, #{type2.inspect}, #{multiplicity2.inspect}, #{opts2.inspect}"
=end

      type1 ||= self
      name1 ||= 
        begin
          x = type1.to_s
          x.sub!(/.*::/, '')
          x[0 .. 0].downcase + x[1 .. -1]
        end
      multiplicity1 ||= (1 .. 1)
      multiplicity1 = _coerce_multiplicity multiplicity1
      opts1 ||= EMPTY_HASH
      name1 = name1.to_s
      name1 = "_#{name1}" if name1 == 'class'
      
      type2 or raise ArgumentError
      name2 ||= 
        begin
          x = type2.to_s
          x.sub!(/.*::/, '')
          x[0 .. 1].downcase + x[1 .. -1]
        end
      multiplicity2 ||= (1 .. 1)
      multiplicity2 = _coerce_multiplicity multiplicity2
      opts2 ||= EMPTY_HASH
      name2 = name2.to_s
      name2 = "_#{name2}" if name2 == 'class'
     
=begin
      $stderr.puts \
"  # _association #{name1.inspect}, #{type1.inspect}, #{multiplicity1.inspect}, #{opts1.inspect},
                 #{name2.inspect}, #{type2.inspect}, #{multiplicity2.inspect}, #{opts2.inspect}"
=end

      end1 = { :name => name1.to_sym, :type => type1, :multiplicity => multiplicity1 }.update(opts1)
      end2 = { :name => name2.to_sym, :type => type2, :multiplicity => multiplicity2 }.update(opts2)
      
      [ [ end1, end2 ], [ end2, end1 ] ].each do | (e, o) |
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
          _class_eval etype, <<"RUBY", __FILE__, __LINE__
  # AssociationEnd #{name} : #{type} #{multiplicity}
  def #{name}
    @#{name}
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
        else
          _class_eval etype, <<"RUBY", __FILE__, __LINE__
  # AssociationEnd #{name} : #{type} #{multiplicity}
  def #{name}
    @#{name} ||= [ ]
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
        end
      end
    end # def

  end # module


  module CodeGeneration
    include CodeGenerationCore
    STEREOTYPES = { } unless defined? STEREOTYPES
    def stereotype *args
      case args.size
      when 0
        STEREOTYPES[self]
      else
        STEREOTYPES[self] = args
      end
    end
    def hasStereotype? x
      ancestors.any? { | e | (s = e.stereotype) && s.include?(x) }
    end

    def property *args
      _generate_property self, *args
    end

    def association *args
      $stderr.puts "  # association #{args.inspect}"
      args[1] ||= self
      args[5] ||= self
      _generate_association *args
    end

    def import *packages
      packages.each do | pkg |
        pkg.constants.each do | c |
          $stderr.puts "  # import #{self}::#{c} = #{pkg}::#{c}"
          v = pkg.const_get(c)
          cv = self.const_get(c) rescue nil
          self.const_set(c, v) if cv != v
        end
      end
    end
  end


  class Factory
    def get name
      cls = Instantiable::INSTANTIABLE_CLASSES[name]
    end

    def create name
      cls = get name
      raise ArgumentError, "cannot find class by #{name}" unless cls
      cls.hasStereotype?(:primitive) ? cls : cls.new
    end

    def new name, *args
      obj = create(name)
      Module === obj ? obj.coerce(*args) : obj._initialize(*args)
    end
  end

  # Basic mixin for all UML instantitable objects.
  module Instantiable
    INSTANTIABLE_CLASSES = { }
    def self.included base
      super
      base.extend(ClassMethods)
      name = base.to_s
      short_name = name.sub(/\A.*::/, '')
      INSTANTIABLE_CLASSES[name.freeze] = 
      INSTANTIABLE_CLASSES[short_name.freeze] = 
      INSTANTIABLE_CLASSES[short_name.to_sym] = 
        base
    end

    module ClassMethods
    end


    def _initialize opts = nil, &blk
      opts ||= EMPTY_HASH
      opts.each do | k, v |
        s = "#{k}="
        if respond_to? s
          send(s, v)
        else
          instance_variable_set("@#{k}", v)
        end
      end
      if block_given?
        instance_eval &blk
      end
      self
    end
    alias :initialize :_initialize

  end 

end # module

end # module


Module.class_eval do
  include RUML::Support::CodeGeneration
end
