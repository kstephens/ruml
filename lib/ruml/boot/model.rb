# frozen_string_literal: true

require 'ruml/boot'
require 'ruml/core/runtime'
require 'ruml/core/primitive_types'
require 'ruml/boot/builder'

module RUML::Boot::Model
  PrimitiveTypes = RUML::Core::PrimitiveTypes

  RUML::Boot::Builder.new(root_namespace: self) do
  namespace :UML do
    import PrimitiveTypes

    # 7.4.2 Abstract Syntax
    class_ :Element, :isAbstract do
      association \
        "+owner : Element 0..1 {readOnly, union}", \
        "+/ownedElement : Element * {readOnly, union}"
    end

    class_ :NamedElement, :isAbstract do
      superClass :Element
      property "+ name : String [0..1]"
      property "+ visibility : VisibilityKind [0..1]"
      property "+ /qualifiedName : String [0..1] {readOnly}" do
        node, path = self, []
        while node
          path << node.name if node && node != ""
          node = node.owner
        end
        path.reverse!.join("::") unless path.empty?
      end
    end

    class_ :TypedElement, :isAbstract do
      superClass :NamedElement
    end

    class_ :PackageableElement, :isAbstract do
      superClass :NamedElement
    end

    # 8.6.22 ValueSpecification [Abstract Class]
    class_ :ValueSpecification, :isAbstract do
      superClass :TypedElement
      generalization :PackageableElement
    end

    # 8.6.12 LiteralSpecification [Abstract Class]
    class_ :LiteralSpecification, :isAbstract do
      superClass :ValueSpecification
    end

    # 7.8.15 Relationship [Abstract Class]
    class_ :Relationship, :isAbstract do
      superClass :Element
    end

    # 7.8.5 DirectedRelationship [Abstract Class]
    class_ :DirectedRelationship, :isAbstract do
      superClass :Relationship
    end

    # 8.15 Relationship [Abstract Class]
    class_ :Relationship, :isAbstract  do
      superClass :Element
      # /relatedElement : Element [1..*]{union} (opposite A_relatedElement_relationship::relationship)
      # Specifies the elements related by the Relationship.
    end

    class_ :Dependency, :isAbstract do
      superClass :Element
      generalization :DirectedRelationship, :PackageableElement
    end

    # 7.7.2 Abstract Syntax
    class_ :OpaqueExpression do
      superClass :Element
      property "body : String [0..*]"
      property "language : String [0..*]"
    end

    class_ :Abstraction do
      superClass :Dependency
      association \
        "+abstraction : Abstraction 0..1 {subsets owner}",
        "+ mapping : OpaqueExpression 0..1 {subsets ownedElement}"
    end

    class_ :Usage do
      superClass :Dependency
    end

    class_ :Realization do
      superClass :Dependency
    end

    class_ :Comment do
      superClass :Element
      property "+ body : String [0..1]"
      association \
        "+ ownedComment : Comment * {subsets ownedElement}",
        "+ owningElement : Element 0..1 {subsets owner}"
      association \
        "+ ownedComment : Comment * {subsets ownedElement}" ,
        "+ annotatedElement : Element *"
    end

    class_ :Namespace do
      superClass :NamedElement
      association \
        "+ /namespace : Namespace 0..1 {readOnly, union, subsets memberNamespace, subsets owner}",
        "+ /ownedMember : NamedElement * {readOnly, union, subsets member, subsets ownedElement}"
      association \
        "+ /memberNamespace : Namespace * {readOnly, union, subsets memberNamespace, subsets owner}",
        "+ /member : NamedElement {readOnly, union}"
    end

    # 8.6.17 StringExpression [Class]

    class_ :StringExpression do
      operation "stringValue() : String {redefines ValueSpecification::stringValue()}"
      association \
        "+owningExpression : StringExpression [0..1]{subsets Element::owner}", \
        "+subExpression : StringExpression [0..*]{ordered, subsets Element::ownedElement}"
    end

    #### PER XMI
    class_ :Package do
      superClass :Namespace
      property "+ URI : String [0..1]"
    end

    class_ :PackageImport do
    end

    class_ :Type do
    end

    class_ :Classifier do
      superClass :Namespace
      property "+isAbstract : Boolean = false"
      property "+ isFinalSpecialization : Boolean" # ???
      association \
        "+ classifier : Classifier *", \
        "+ /general : Classifier *"
    end

    class_ :Class do
      superClass :Classifier
      property "+isAbstract : Boolean = false {redefines isAbstract}"
      property "+isActive : Boolean = false"
    end

    class_ :Constraint do
    end

    class_ :OpaqueExpression do
      property "+ body : String [*] {ordered, nonunique}"
      property "+ language : String [*] {ordered}"
    end

    class_ :Generalization do
      property "+ isSubstitutable : Boolean [0..1] = true"
      association \
        "+specific : Classifier 1 {subsets source,
subsets owner}", \
        "+generalization : Generalization {subsets ownedElement, subsets directedRelationship}"
      association \
        "+general : Classifier 1 {subsets target}", \
        "+ generalization : Generalization* {subsets
directedRelationship}"
    end

    class_ :MultiplicityElement do
      property "+isOrdered : Boolean = false"
      property "+isUnique : Boolean = true"
      property "+/lower : Integer [0..1] = 1"
      property "+/upper : UnlimitedNatural [0..1] = 1"
    end

    class_ :StructuralFeature do
      generalization :MultiplicityElement, :TypedElement # :Feature
      property "isReadOnly : Boolean [1..1] = false"
    end

    class_ :Property do
      generalization :StructuralFeature
      property "+aggregation : AggregationKind = none"
      property "+/default : String [0..1]"
      property "+/isComposite : Boolean"
      property "+isDerived : Boolean = false"
      property "+isDerivedUnion : Boolean = false"
      property "+isID : Boolean = false"
      association \
        "+ classifier : Classifier 0..1 {readOnly, union, subsets featuringClassifier,
subsets redefinitionContext}", \
        "+ /attribute : Property * {ordered, readOnly, union, subsets
feature, subsets redefinableElement}"
      association \
        "+ ownedAttribute : Property * {ordered, subsets attribute, subsets ownedMember, redefines ownedAttribute}",
        "+ class : Class 0..1 {subsets namespace, subsets
structuredClassifier, subsets classifier}"
      association \
        "+ qualifier : Property * {ordered, subsets ownedElement}",
        "+ associationEnd : Property 0..1 {subsets owner}"
      association \
        "+ /opposite : Property 0..1",
        "+ property : Property 0..1"
      association \
        "+ subsettedProperty : Property * {subsets redefinedElement}",
        "+ property : Property *"
      association \
        "+ property : Property * {subsets
redefinableElement}",
        "+ redefinedProperty : Property * {subsets redefinedElement}"
    end

    class_ :Association do
      generalization :Relationship, :Classifier
      property "+ isDerived : Boolean = false"
      association \
        "+owningAssociator : Association 0..1 {composite, subsets featuringClassifier, subsets namespace, subsets association, subsets redefinitionContext}",
        "+ownedEnd : Property * {ordered, subsets feature, subsets redefinableElement, subsets memberEnd, subsets ownedMember}"
      association \
        "+ association : Association 0..1 {subsets owningAssociation}",
        "+ navigableOwnedEnd : Property * {subsets ownedEnd}"
      association \
        "+ association : Association 0..1 {subsets memberNamespace}",
        "+ memberEnd : Property 2..* {ordered, subsets member}"
      association \
        "+ association : Association 0..1 {subsets relationship}",
        "+ memberEnd : Type 1..* {readOnly, subsets relatedElement}"
    end

    class_ :AssociationClass do
      superClass :Association, :Class
    end

    # class_ :LiteralInteger
    # end
    # class_ :LiteralUnlimitedNatural
    # end
    # class_ :LiteralBoolean
    # end
    class_ :Parameter do
      superClass :MultiplicityElement
      property "+direction : ParameterDirectionKind = in"
    end
    class_ :Operation do
      superClass :NamedElement
      property "+/isOrdered : Boolean = false{readOnly}"
      property "+isQuery : Boolean = false"
      property "+/isUnique : Boolean = true{readOnly}"
      property "+/lower : Integer [0..1] = 1{readOnly}"
      property "+/upper : UnlimitedNatural [0..1] = 1{readOnly}"
      association \
        "+ operation : Operation 0..1 {subsets ownerFormalParam}", \
        "+ ownedParameter : Parameter * {ordered, redefines ownedParameter}"
    end
    class_ :ParameterDirectionKind do #
      stereotype :enumeration
      enum :in
      enum :inout
      enum :out
      enum :return
    end

    class_ :Stereotype do
      superClass :Class
    end

    class_ :Association do
      property "+isDerived : Boolean = false"
      association \
        "+ ownedEnd : Property * {ordered, subsets feature, subsets redefinableElement, subsets memberEnd, subsets ownedMember}", \
        "+ owningAssociation : Association 0..1 {subsets featuringClassifier, subsets namespace, subsets association, subsets redefinitionContext}"
      association \
        "+ navigableOwnedEnd : Property * {subsets ownedEnd}", \
        "+ association : Association 0..1 {subsets owningAssociation}"
      association \
        "+ memberEnd : Property 2..* {ordered, subsets member}", \
        "+ association : Association 0..1 {subsets memberNamespace}"
    end

    class_ :InstanceValue do
    end

    class_ :Enumeration do
      superClass :NamedElement
      superClass :Class
    end

    class_ :EnumerationLiteral do
      superClass :NamedElement
      association \
        "+enumeration : Enumeration [1..1] {subsets namespace}", \
        "+ownedLiteral : EnumerationLiteral [0..*] {ordered, subsets ownedMember}"
      # association \
      #   "+/classifier : Enumeration [1..1] {redefines InstanceSpecification::classifier}", \
      #   "+ownedLiteral : EnumerationLiteral [0..*] {ordered, subsets ownedMember}"
    end

    class_ :VisibilityKind do #
      stereotype :enumeration
      enum :public    # "+"
      enum :private   # "-"
      enum :protected # "#"
      enum :package   # "~"
    end

    class_ :AggregationKind do #
      stereotype :enumeration
      enum :none
      enum :shared       # open diamond
      enum :composite    # filled diamond
    end

    class_ :AggregationKind do
      stereotype :enumeration
      enum :none
      enum :shared       # open diamond
      enum :composite    # filled diamond
    end
  end

  package :MOF do
    import PrimitiveTypes
    import "UML"

    # binding.pry

    namespace :Reflection do
      class_ :Element do
        operation "+getMetaClass() : Class {query}"
        operation "+container() : Element {query}"
        operation "+isInstanceOfType(type : Class, includesSubtypes: Boolean) : Boolean {query}"
      end
    end

    namespace :Extension do
      class_ :Tag do
        generalization "Reflection::Element"
        property "+ name : String"
        property "+ value : String"
        association \
          "+tag : Tag",
          "+element : Reflection::Element 0..*"
      end
    end
  end
  # binding.pry
  package :MOFEXT do
    import "MOF::Extension"
  end
end.compile(target: :Ruby).eval_code()
# binding.pry
end
