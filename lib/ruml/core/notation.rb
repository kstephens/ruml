# frozen_string_literal: true

require 'ruml'

module RUML::Core
  class NotationError < RUML::Error; end

  class Notation
    def initialize(factory)
      @factory = factory
    end

    # Parses a UML property string, e.g. "+ /name : String [0..1] = x {readOnly}",
    # assigns its attributes to obj and returns the captured parts as a Hash.
    def property x
      _parse(PROPERTY, x, :UML, :Property) do | h |
        pms = modifiers(h[:modifiers])
        range = multiplicity(h[:multiplicity])
        prop = {
          visibility: visibility(h[:visibility]),
          isDerived: !!h[:isDerived],
          name: h[:name],
          type: h[:type]&.to_s,
          lower: range.begin,
          upper: range.end,
          aggregation: :none,
          default: h[:default],
          isOrdered: pms.include?("ordered") && !pms.include?("unordered"),
          isUnique: !pms.include?("nonunique"),
          isReadOnly: pms.include?("readOnly"),
          isDerivedUnion: !! pms.include?("union"),
          isID: pms.include?("id"),
          # !!! can these be outofband such they are compatible
          # with the metamodel props?
          # should the Factor handle it?
          subsets: subsets(pms),     # !!! NON-STANDARD
          redefines: redefines(pms), # !!! NON-STANDARD
          opposite: h[:opposite],    # !!! NON-STANDARD
        }
        if pms.include?("seq") || pms.include?("sequence")
          prop.update(
            isUnique: false,
            isOrdered: true,
          )
        end
        prop
      end
    end

    def operation x
      _parse(OPERATION, x, :UML, :Operation) do | h |
        prefix = _match(OPERATION_PREFIX, h[:operation_prefix])
        suffix = _match(OPERATION_SUFFIX, h[:operation_suffix])
        mods = modifiers(suffix[:modifiers])
        range = multiplicity(suffix[:multiplicity])
        params = split_by_comma(h[:parameters]).map do | param |
          parameter(param)
        end
        op = {
          visibility: visibility(prefix[:visibility]),
          isDerived: !!prefix[:isDerived],
          name: prefix[:name],
          parameter: params,
        }
        # !!! delete.
        # binding.pry if $stop_here
        if suffix[:type]
          op[:parameter] << _new(
            :UML, :Parameter,
            type: suffix[:type],
            name: "return",
            direction: :return,
            lower: range.begin,
            upper: range.end,
            default: nil,
          )
        end
        op
      end
    end

    def parameter x
      _parse(PARAMETER, x, :UML, :Parameter) do | h |
        mods = modifiers(h[:modifiers])
        range = multiplicity(h[:multiplicity])
        # !!! use Factory to map enums?
        # this could be simpler.
        # default then validate.
        direction = [:in, :out, :inout, :return].find{|dir| mods.include?(dir.to_s)} || :in
        {
          name: h[:name],
          type: h[:type]&.to_s,
          direction: direction,
          lower: range.begin,
          upper: range.end,
          default: h[:default],
        }
      end
    end

    def direction x
      # !!! 
    end 
    
    def visibility s
      # !!! default then validate.
      # move to factory/introspection
      VISIBILITY_NAME.fetch(s || '+')
    end

    def subsets pms
      modifier_values(pms, 'subsets')
    end

    def redefines pms
      modifier_values(pms, 'redefines')
    end

    def modifiers s
      split_by_comma(s).map! do |pm|
        pm.strip!
        pm.split(/\s+/).join(' ') unless pm[0] == "#"
      end.compact
    end

    def modifier_values pms, key
      pms
      .select { |pm| pm.start_with?("#{key} ") }
      .map! { |pm| pm.sub("#{key} ", "") }
    end

    # !!! refactor into Misc?
    def split_by_comma(s)
      (s || '').strip.split(/\s*,\s*/).map(&:strip)
    end

    # !!! refactor to core/misc.rb
    def multiplicity m
      case m
      when nil
        1..1
      when ::Integer
        m..m
      when ::Range
        m
      when '*', :*
        0 .. -1
      when /\A(\d+)\Z/
        ($1.to_i) .. ($1.to_i)
      when /\A(\d+)\.\.(\d+)\Z/
        ($1.to_i) .. ($2.to_i)
      when /\A(\d+)\.\.\*\Z/
        ($1.to_i) .. -1
      else
        raise NotationError, "invalid multiplicity : #{m.inspect}"
      end
    end

    def _parse rx, str, ns, type
      str = str.gsub(/\s/, ' ')
      str = str.strip
      return unless (match = _match(rx, str))
      properties = (yield match) || match
      mods = modifiers(match[:modifiers])
      range = multiplicity(match[:multiplicity])
      notation = {
        notation: str,
        match: match,
        name: match[:name],
        modifiers: mods,
        multiplicity: range,
        properties: properties,
      }
      # properties[:_notation] = notation # ???
      obj = _new(ns, type, properties)
      # !!! can this be out of band?
      # introspection/factory responsiblitu?
      obj._.metatype = type.to_sym
      obj._.notation = str # notation
      obj._.properties = properties # !!!
      # obj._.match = match
      # obj._.notation = str
      obj
    end

    def _new ns, type, properties
      @factory.new(ns, type, properties)
    end

    def _match rx, s
      if s && (m = rx.match(s))
        m.named_captures.transform_keys(&:to_sym)
      end
    end

    VISIBILITY_NAME = {
      '+' => :public,
      '-' => :private,
      '#' => :protected,
      '~' => :package,
    }
    INTEGER = %r{(?<integer>[-+]?\d+)}
    FLOAT = %r{(?<float>[-+]?(?:\d+\.\d*|\.\d+)(?:[eE][-+]?\d+)?)}
    STRING = %r{(?<string>"(?:\\.|[^"])*")}
    BOOLEAN = %r{(?<boolean>true|false)}
    KEYWORD = %r{(?<keyword>[_a-zA-Z][_a-zA-Z0-9]*)}
    CONSTANT = %r{(?:#{STRING}|#{FLOAT}|#{INTEGER}|#{BOOLEAN}|#{KEYWORD})}
    IDENTIFIER = %r{(?:[_a-zA-Z][_a-zA-Z0-9]*)}
    QUALIFIED_IDENTIFIER = %r{#{IDENTIFIER}(?:::#{IDENTIFIER})*}

    VISIBILITY = %r{(?<visibility>[-+\#~])}
    IS_DERIVED = %r{(?<isDerived>/)}
    NAME = %r{(?<name>#{IDENTIFIER})}
    QUALIFIED_NAME = %r{(?<name>#{QUALIFIED_IDENTIFIER})}
    TYPE = %r{(?::\s*(?<type>#{QUALIFIED_IDENTIFIER}))}
    MULTIPLICITY = %r{(?:\[?(?<multiplicity>\d+(?:\.\.(?:\d+|\*))?|\*)\]?)}
    DEFAULT = %r{(?:=\s*(?<default>#{CONSTANT}))}
    MODIFIERS = %r{(?:\{(?<modifiers>[^\}]*)\})}
    OPPOSITE = %r{(?:\(opposite\s+(?<opposite>[^\)]*)\))}

    PROPERTY = %r{\A
      \s*#{VISIBILITY}?
      \s*#{IS_DERIVED}?\
      \s*#{NAME}
      \s*#{TYPE}?
      \s*#{MULTIPLICITY}?
      \s*#{DEFAULT}?
      \s*#{MODIFIERS}?
      \s*#{OPPOSITE}?
      \s*
    \Z}x
    PARAMETER = %r{
      (?:
      \s*#{NAME}
      \s*#{TYPE}
      \s*#{MULTIPLICITY}?
      \s*#{DEFAULT}?
      \s*#{MODIFIERS}?
      \s*
      )
    }x
    PARAMETERS = %r{\((?<parameters>(?:#{PARAMETER}(?:,#{PARAMETER})*)?)\)}
    OPERATION_PREFIX = %r{\A
      \s*#{VISIBILITY}?
      \s*#{IS_DERIVED}?
      \s*#{NAME}
    }x
    OPERATION_SUFFIX = %r{
      \s*#{TYPE}?
      \s*#{MULTIPLICITY}?
      \s*#{DEFAULT}?
      \s*#{MODIFIERS}?
      \s*
    \Z}x
    OPERATION = %r{
      (?<operation_prefix>#{OPERATION_PREFIX})
      #{PARAMETERS}
      (?<operation_suffix>#{OPERATION_SUFFIX})
    \Z}x
  end
end

=begin

Properties:

9.5.4 Notation
The following general notation is defined for Properties.
NOTE. Some specializations of Property may also have additional notational forms. These are covered in the
appropriate Notation sub clauses of those classes.
<property> ::= [<visibility>] [‘/’] <name> [‘:’ <prop-type>] [‘[‘ <multiplicity-range> ‘]’] [‘=’ <default>] [‘{‘
<prop-modifier > [‘,’ <prop-modifier >]* ’}’]
where:
 <visibility> is the visibility of the Property. (See VisibilityKind - sub clause 7.4.)
<visibility> ::= ‘+’ | ‘-‘ | ‘#’ | ‘~’
 ‘/’ signifies that the Property is derived.
 <name> is the name of the Property, or the empty string if the Property has no name.
 <prop-type> is the name of the Classifier that is the type of the Property.
 <multiplicity-range> is the multiplicity range of the Property. If this term is omitted, it implies a multiplicity
of 1 (exactly one). (See MultiplicityElement – sub clause 7.5.)
 <default> is an expression that evaluates to the default value or values of the Property.
 <prop-modifier> indicates a modifier that applies to the Property.
<prop-modifier> ::= ‘readOnly’ | ‘union’ | ‘subsets’ <property-name> |
‘redefines’ <property-name> | ‘ordered’ | ‘unordered’ | ‘unique’ | ‘nonunique’ | ‘seq’ | ‘sequence’ |
‘id’ | <prop-constraint>
where:
 ‘readOnly’ means that the Property is read only.
 ‘union’ means that the Property is a derived union of its subsets.
 ‘subsets’ <property-name> means that the Property is a proper subset of the Property identified by
<property-name>, where <property-name> may be qualified.
Unified Modeling Language 2.5.1 113
 ‘redefines’ <property-name> means that the Property redefines an inherited Property identified by
<property-name>, where <property-name> may be qualified.
 ‘ordered’ means that the Property is ordered, i.e., isOrdered = true.
 ‘unordered’ means that the Property is not ordered, i.e., isOrdered = false.
 ‘unique’ means that there are no duplicates in a multi-valued Property, i.e., isUnique = true.
 ‘nonunique’ means that there may be duplicates in a multi-valued Property, i.e., isUnique = false.
 ‘seq’ or ‘sequence’ means that the property represents an ordered bag, i.e., isUnique = false and
isOrdered = true
 ‘id’ means that the Property is part of the identifier for the class.
 <prop-constraint> is an expression that specifies a constraint that applies to the Property.
The notation for qualifiers is defined in 11.5 Associations.
The notation for the aggregation of a Property is defined in 11.5 Associations.
In a Classifier, the type, visibility, default, multiplicity, property string may be suppressed from being displayed, even if
there are values in the model.
In a Classifier, the individual properties of an attribute may be shown in columns rather than as a continuous string.
In a Classifier, an attribute may also be shown using association notation, where only an aggregation adornment (hollow
or filled diamond) may be shown at the tail of the arrow.
The notation for a ConnectableElementTemplateParameter used to parameterize a template Classifier by a Property is
this:
<connectable-element-template-parameter> ::= <property-name> ‘: Property’

=end

