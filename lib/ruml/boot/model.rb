# frozen_string_literal: true

require 'ruml/core/runtime'
require 'ruml/core/primitive_types'
require 'ruml/boot/builder'

module RUML::Boot::Model
  RUML::Boot::Builder.new(root: self).begin!
  PrimitiveTypes = RUML::Core::PrimitiveTypes

  module UML
    ruml.import "PrimitiveTypes"

    class Element
      ruml.association \
        "+owner : Element 0..1 {readOnly, union}", \
        "+/ownedElement : Element * {readOnly, union}"
    end
    class NamedElement < Element
      ruml.property "+ name : String [0..1]"
      ruml.property "+ visibility : VisibilityKind [0..1]"
      ruml.property "+ /qualifiedName : String [0..1] {readOnly}" do
        node, path = self, nil
        while node
          (path ||= []) << node.name if node && node != ""
          node = node.owner
        end
        path.reverse!.join("::") if path
      end
    end
    class Comment < Element
      ruml.property "+ body : String [0..1]"
      ruml.association \
        "+ ownedComment : Comment * {subsets ownedElement}",
        "+ owningElement : Element 0..1 {subsets owner}"
      ruml.association \
        "+ ownedComment : Comment * {subsets ownedElement}" ,
        "+ annotatedElement : Element *"
    end

    class Namespace < NamedElement
      ruml.association \
        "+ /namespace : Namespace 0..1 {readOnly, union, subsets memberNamespace, subsets owner}",
        "+ /ownedMember : NamedElement * {readOnly, union, subsets member, subsets ownedElement}"
      ruml.association \
        "+ /memberNamespace : Namespace * {readOnly, union, subsets memberNamespace, subsets owner}",
        "+ /member : NamedElement {readOnly, union}"
    end

    class StringExpression
    end
    #### PER XMI
    class Package < Namespace
      ruml.property "+ URI : String [0..1]"
    end
    class PackageImport
    end
    class Type
    end
    class Classifier < Namespace
      ruml.property "+isAbstract : Boolean = false"
      ruml.property "+ isFinalSpecialization : Boolean" # ???
      ruml.association \
        "+ classifier : Classifier *", \
        "+ /general : Classifier *"
      ruml.association \
        "+ classifier : Classifier 0..1 {readOnly, union, subsets featuringClassifier,
subsets redefinitionContext}", \
        "+ /attribute : Property * {ordered, readOnly, union, subsets
feature, subsets redefinableElement}"
    end
    class Class < Classifier
    end
    class Constraint
    end
    class OpaqueExpression
      ruml.property "+ body : String [*] {ordered, nonunique}"
      ruml.property "+ language : String [*] {ordered}"
    end
    class Generalization
      ruml.property "+ isSubstitutable : Boolean [0..1] = true"
      ruml.association \
        "+specific : Classifier 1 {subsets source,
subsets owner}", \
        "+generalization : Generalization {subsets ownedElement, subsets directedRelationship}"
      ruml.association \
        "+general : Classifier 1 {subsets target}", \
        "+ generalization : Generalization* {subsets
directedRelationship}"
    end
    class MultiplicityElement
      ruml.property "+isOrdered : Boolean = false"
      ruml.property "+isUnique : Boolean = true"
      ruml.property "+/lower : Integer [0..1] = 1"
      ruml.property "+/upper : UnlimitedNatural [0..1] = 1"
    end
    class StructuralFeature < MultiplicityElement
      ruml.property "isReadOnly : Boolean [1..1] = false"
    end
    class Property < StructuralFeature
      ruml.property "+aggregation : AggregationKind = none"
      ruml.property "+/default : String [0..1]"
      ruml.property "+/isComposite : Boolean"
      ruml.property "+isDerived : Boolean = false"
      ruml.property "+isDerivedUnion : Boolean = false"
      ruml.property "+isID : Boolean = false"
      ruml.association \
        "+ ownedAttribute : Property * {ordered, subsets attribute, subsets ownedMember, redefines ownedAttribute}",
        "+ class : Class 0..1 {subsets namespace, subsets
structuredClassifier, subsets classifier}"
      ruml.association \
        "+ qualifier : Property * {ordered, subsets ownedElement}",
        "+ associationEnd : Property 0..1 {subsets owner}"
      ruml.association \
        "+ /opposite : Property 0..1",
        "+ property : Property 0..1"
      ruml.association \
        "+ subsettedProperty : Property * {subsets redefinedElement}",
        "+ property : Property *"
      ruml.association \
        "+ property : Property * {subsets
redefinableElement}",
        "+ redefinedProperty : Property * {subsets redefinedElement}"
    end

    class Association
      ruml.superClass :Relationship, :Classifier
      ruml.property "+ isDerived : Boolean = false"
      ruml.association \
        "+owningAssociator : Association 0..1 {composite, subsets featuringClassifier,
subsets namespace, subsets
association, subsets
redefinitionContext}",
        "+ownedEnd : Property * {ordered, subsets feature, subsets
redefinableElement, subsets
memberEnd, subsets
ownedMember}"
      ruml.association \
        "+ association : Association 0..1 {subsets owningAssociation}",
        "+ navigableOwnedEnd : Property * {subsets ownedEnd}"
      ruml.association \
        "+ association : Association 0..1 {subsets memberNamespace}",
        "+ memberEnd : Property 2..* {ordered, subsets member}"
      ruml.association \
        "+ association : Association 0..1 {subsets relationship}",
        "+ memberEnd : Type 1..* {readOnly, subsets relatedElement}"
    end
    class AssociationClass < Association
      ruml.superClass :Class
    end

    # class LiteralInteger
    # end
    # class LiteralUnlimitedNatural
    # end
    # class LiteralBoolean
    # end
    class Parameter < MultiplicityElement
      ruml.property "+direction : ParameterDirectionKind = in"
    end
    class Operation < NamedElement
      ruml.property "+/isOrdered : Boolean = false{readOnly}"
      ruml.property "+isQuery : Boolean = false"
      ruml.property "+/isUnique : Boolean = true{readOnly}"
      ruml.property "+/lower : Integer [0..1] = 1{readOnly}"
      ruml.property "+/upper : UnlimitedNatural [0..1] = 1{readOnly}"
      ruml.association \
        "+ operation : Operation 0..1 {subsets ownerFormalParam}", \
        "+ ownedParameter : Parameter * {ordered, redefines ownedParameter}"
    end
    class ParameterDirectionKind # < ruml.enumeration
      ruml.enum :in
      ruml.enum :inout
      ruml.enum :out
      ruml.enum :return
    end
    class Association
      ruml.property "+isDerived : Boolean = false"
      ruml.association \
        "+ ownedEnd : Property * {ordered, subsets feature, subsets redefinableElement, subsets memberEnd, subsets ownedMember}", \
        "+ owningAssociation : Association 0..1 {subsets featuringClassifier, subsets namespace, subsets association, subsets redefinitionContext}"
      ruml.association \
        "+ navigableOwnedEnd : Property * {subsets ownedEnd}", \
        "+ association : Association 0..1 {subsets owningAssociation}"
      ruml.association \
        "+ memberEnd : Property 2..* {ordered, subsets member}", \
        "+ association : Association 0..1 {subsets memberNamespace}"
    end
    class InstanceValue
    end
    class Enumeration < Class
      ruml.association \
        "+enumeration : Enumeration [1..1] {subsets namespace}", \
        "+ownedLiteral : EnumerationLiteral [0..*] {ordered, subsets ownedMember}"
    end
    class EnumerationLiteral
      ruml.property "+ name: String"
    end
    class VisibilityKind # < ruml.enumeration
      ruml.enum :public    # "+"
      ruml.enum :private   # "-"
      ruml.enum :protected # "#"
      ruml.enum :package   # "~"
    end
    class AggregationKind # < ruml.enumeration
      ruml.enum :none
      ruml.enum :shared       # open diamond
      ruml.enum :composite    # filled diamond
    end
    class AggregationKind # < ruml.enumeration
      ruml.enum :none
      ruml.enum :shared       # open diamond
      ruml.enum :composite    # filled diamond
    end
  end
  module MOF
    ruml.import "PrimitiveTypes"
    ruml.import "UML"

    # Class = UML::Class
    # Boolean = UML::Boolean

    module Reflection
      class Element
        ruml.operation "+getMetaClass() : Class {query}"
        ruml.operation "+container() : Element {query}"
        ruml.operation "+isInstanceOfType(type : Class, includesSubtypes: Boolean) : Boolean {query}"
      end
    end

    module Extension
      class Tag < Reflection::Element
        ruml.property "+ name : String"
        ruml.property "+ value : String"
        ruml.association \
          "+tag : Tag",
          "+element : Reflection::Element 0..*"
      end
    end
  end
  module MOFEXT
    Tag = MOF::Extension::Tag
  end
  MODEL = ruml.end!
end
