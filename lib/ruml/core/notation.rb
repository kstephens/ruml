# frozen_string_literal: true

require 'ruml'

module RUML::Core
  class NotationError < RUML::Error; end

  class Notation
    # Parses a UML property string, e.g. "+ /name : String [0..1] = x {readOnly}",
    # assigns its attributes to obj and returns the captured parts as a Hash.
    def property x, obj
      return unless (h = parse_end(x))
      apply_end h, obj
      h
    end

    def apply_end h, obj
      obj.visibility = VISIBILITY.fetch(h[:visibility] || '+')
      obj.isDerived = !!h[:derived]
      obj.name = h[:name]&.to_sym
      obj.type = h[:prop_type]&.to_sym
      obj.default = h[:default]
      pms = h[:prop_modifiers]
      obj.isOrdered = pms.include?("ordered") && !pms.include?("unordered")
      obj.isUnique = !pms.include?("nonunique")
      if pms.include?("seq") || pms.include?("sequence")
        obj.isUnique = false
        obj.isOrdered = true
      end
      obj.isReadOnly = pms.include?("readOnly")
      obj.isDerivedUnion = !! pms.include?("union")
      obj.isID = pms.include?("id")
      range = multiplicity(h[:multiplicity_range])
      obj.lower = range.begin
      obj.upper = range.end # -1 is unbounded.
      obj.subsets = h[:subsets] # !!! use actual models
      obj.redefines = h[:redefines]  # !!! use actual models
      obj
    end

    def parse_end x
      return unless (m = PROPERTY.match(x))
      h = m.named_captures.transform_keys(&:to_sym)
      h[:prop_modifiers] = (h[:prop_modifier] || '').strip.split(/\s*,\s*/).map! do |pm|
        pm.split(/\s+/).join(' ')
      end
      h[:subsets] = modifier_values(h[:prop_modifiers], 'subsets')
      h[:redefines] = modifier_values(h[:prop_modifiers], 'redefines')
      h
    end

    def modifier_values pms, key
      pms.select { |pm| pm.start_with?("#{key} ") }.map { |pm| pm.sub("#{key} ", "").to_sym }
    end

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

    VISIBILITY = {
      '+' => :public,
      '-' => :private,
      '#' => :protected,
      '~' => :package,
    }
    PROPERTY = %r{\A
      \s*
      (?<visibility>[-+\#~])?
      \s*
      (?<derived>/)?
      \s*
      (?<name>[_a-zA-Z]\w*)?
      \s*
      (?::\s*(?<prop_type>\w+))?
      \s*
      (?:\[?(?<multiplicity_range>\d+(?:\.\.(?:\d+|\*))?|\*)\]?)?
      \s*
      (?:=\s*(?<default>[^\s{]+))?
      \s*
      (?:\{(?<prop_modifier>[^}]+)\})?
      \s*
      \z}x
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

