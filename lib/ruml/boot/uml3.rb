# frozen_string_literal: true

require 'ruml/core/runtime'
require 'ruml/core/primitive_types'
require 'ruml/boot/builder'

module RUML::Boot::Model
  module UML
    # ruml = RUML::Boot::Builder.new
    class Element
      ruml :association, \
        "Element +owner 0..1 {readOnly, union}", \
        "Element + /ownedElement * {readOnly, union}"
    end
    class NamedElement < Element
      ruml :property, "+ name : String [0..1]"
      ruml :property, "+ /qualifiedName : String [0..1] {readOnly}"
      ruml :property, "+ visibility : VisibilityKind [0..1]"
    end
    class Comment < Element
      ruml :property, "+ body : String [0..1]"
      ruml :association, \
        "Element + owningElement 0..1 {subsets owner}", \
        "Comment + ownedComment * {subsets ownedElement}"
      ruml :association, \
        "Element + annotatedElement *", \
        "Comment + ownedComment * {subsets ownedElement}"
    end
    class Namespace < NamedElement
      ruml :association, \
        "NamedElement + /ownedMember * {readOnly, union, subsets member, subsets ownedElement}", \
        "Namespace + /namespace 0..1 {readOnly, union, subsets memberNamespace, subsets owner}"
      ruml :association, \
        "NamedElement + /member {readOnly, union}", \
        "Namespace + /memberNamespace * {readOnly, union, subsets memberNamespace, subsets owner}"
    end
    class StringExpression
    end
    #### PER XMI
    class Package < Namespace
      ruml :property, "+ URI : String [0..1]"
    end
    class PackageImport
    end
    class Classifier
      ruml :property, "+isAbstract : Boolean = false"
      ruml :property, "+ isFinalSpecialization : Boolean" # ???
      ruml :association, \
        "Classifier + classifier *", \
        "Classifier + /general *"
    end
    class Class < Classifier
    end
    class Constraint
    end
    class OpaqueExpression
    end
    class Generalization
      ruml :property, "+ isSubstitutable : Boolean [0..1] = true"
      ruml :association, \
        "Classifier +specific 1 {subsets source,
subsets owner}", \
        "Generalization +generalization {subsets ownedElement, subsets directedRelationship}"
      ruml :association, \
        "Classifier +general 1 {subsets target}", \
        "Generalization + generalization * {subsets
directedRelationship}"
    end
    class MultiplicityElement
      ruml :property, "+isOrdered : Boolean = false"
      ruml :property, "+isUnique : Boolean = true"
      ruml :property, "+/lower : Integer [0..1] = 1"
      ruml :property, "+/upper : UnlimitedNatural [0..1] = 1"
    end
    class StructuralFeature < MultiplicityElement
      ruml :property, :+, :isReadOnly , :Boolean, :==, false
    end
    class Property < StructuralFeature
      ruml :property, "+aggregation : AggregationKind = none"
      ruml :property, "+/default : String [0..1]"
      ruml :property, "+/isComposite : Boolean"
      ruml :property, "+isDerived : Boolean = false"
    end
    # class LiteralInteger
    # end
    # class LiteralUnlimitedNatural
    # end
    # class LiteralBoolean
    # end
    class Operation
      ruml :property, "+/isOrdered : Boolean = false{readOnly}"
      ruml :property, "+/isUnique : Boolean = true{readOnly}"
      ruml :property, "+/lower : Integer [0..1] = 1{readOnly}"
      ruml :property, "+/upper : UnlimitedNatural [0..1] = 1{readOnly}"
      ruml :association, \
        "Operation + operation 0..1 {subsets ownerFormalParam}", \
        "Parameter + ownedParameter * {ordered, redefines ownedParameter}"
    end
    class Parameter < MultiplicityElement
      ruml :property, "+direction : ParameterDirectionKind = in"
    end
    class ParameterDirectionKind # < ruml.enumeration
      ruml :enum, :in
      ruml :enum, :inout
      ruml :enum, :out
      ruml :enum, :return
    end
    class Association
      ruml :property, "+ isDerived : Boolean = false"
      ruml :association, \
        "Property + ownedEnd * {ordered, subsets feature, subsets redefinableElement, subsets memberEnd, subsets ownedMember}", \
        "Association + owningAssociation 0..1 {subsets featuringClassifier, subsets namespace, subsets association, subsets redefinitionContext}"
      ruml :association, \
        "Property + navigableOwnedEnd * {subsets ownedEnd}", \
        "Association + association 0..1 {subsets owningAssociation}"
      ruml :association, \
        "Property + memberEnd 2..* {ordered, subsets member}", \
        "Association + association 0..1 {subsets memberNamespace}"
    end
    class InstanceValue
    end
    class Enumeration < Class
    end
    class EnumerationLiteral
      ruml :property, "+ name: String"
    end
    class VisibilityKind # < ruml.enumeration
      ruml :enum, :public    # "+"
      ruml :enum, :private   # "-"
      ruml :enum, :protected # "#"
      ruml :enum, :package   # "~"
    end
    class AggregationKind # < ruml.enumeration
      ruml :enum, :none
      ruml :enum, :shared       # open diamond
      ruml :enum, :composite    # filled diamond
    end
  end
  module MOFEXT
    class Tag
    end
  end
  ruml.end!
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

