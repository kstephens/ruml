# frozen_string_literal: true

require 'ruml/core/runtime'
require 'ruml/core/primitive_types'


module RUML::Boot
  module UML
    PrimitiveTypes = ::RUML::Core::PrimitiveTypes
    include ::RUML::Core::PrimitiveTypes

    module Core
      module Abstractions
        module Elements
          module Element
          end
        end # Elements

        module Ownerships
          module Element
            include Elements::Element
          end

          ruml :association, \
          :owner,        Element, 0..1, { :aggregation => true, :union => true },
          :ownedElement, Element, :*,   { :union => true }

          def allOwnedElements
            acc = [ ]
            stk = [ self ]
            while obj = stk.pop
              unless acc.include?(obj)
                acc << obj
                stk.push(*obj.ownedElement)
              end
            end
            acc
          end

          def mustBeOwned
            true
          end
        end # Ownerships

        module Relationships
          module Relationship
            include Ownerships::Element
          end

          module DirectedRelationship
            include Relationship
          end

          ruml :association, \
          nil,             Relationship,        :*,     { :navigable => false },
          :relatedElement, Ownerships::Element, '1..N', { :readOnly => true, :union => true }

          ruml :association, \
          nil,     Relationship,        :*,     { :navigable => false },
          :source, Ownerships::Element, '1..N', { :subsets => :relatedElement, :readOnly => true, :union => true }

          ruml :association, \
          nil,     Relationship,        :*,     { :navigable => false },
          :target, Ownerships::Element, '1..N', { :subsets => :relatedElement, :readOnly => true, :union => true }

        end # Relationships

        module Namespaces
          module NamedElement
            include Ownerships::Element

            ruml :property, :name, PrimitiveTypes::String

            def qualifiedName
              allNamespaces.join(separator)
            end

            SEPARATOR = '::'.freeze unless defined? SEPARATOR
            def separator
              SEPARATOR
            end

            def inspect
              "\#<#{self.class} #{name.inspect} ...>"
            end
          end

          module Namespace
            include NamedElement
          end

          ruml :association, \
          :namespace,   Namespace,     0..1, { :readOnly => true, :union => true, :subsets => :owner,  },
          :ownedMember, NamedElement,  :*, { :readOnly => true, :union => true, :subsets => [ :member, :ownedElement ], }

          ruml :association, \
          :owner,       Namespace,     :*, { :navigable => false },
          :member,      NamedElement,  :*, { :readOnly => true, :union => true, }

        end # Namespaces


        module Expressions
          module ValueSpecification
            include Ownerships::Element
          end

          class OpaqueExpression
            include RUML::Core::Runtime::Instantiable
            include ValueSpecification
            ruml :property, :body, ::String, :*, { :ordered => true }
            ruml :property, :language, ::String, :*, { :ordered => true }
          end

          class Expression
            include RUML::Core::Runtime::Instantiable
            include ValueSpecification
            ruml :property, :symbol, ::String
          end

          ruml :association, \
          :expression, Expression,         0..1, { :subsets => :owner, :aggregation => true },
          :operand,    ValueSpecification, :*,   { :subsets => :ownedElement, :ordered => true }
        end # Expressions


        module Classifiers
          module Classifier
            include Namespaces::Namespace
          end # Classifier

          module Feature
            include Namespaces::NamedElement
          end # Feature

          ruml :association, \
          :featuringClassifier, Classifier, :*, { },
          :feature,             Feature,    :*, { :subsets => :member, :union => true }
        end # Classifiers


        module TypedElements
          module Type
            include Namespaces::NamedElement
          end

          module TypedElement
            include Namespaces::NamedElement
          end

          ruml :association, \
          nil, TypedElement, :*, { :navigable => false },
          :type, Type, 0..1, { }
        end # TypedElements


        module StructuralFeatures
          module StructuralFeature
            include TypedElements::TypedElement
            include Classifiers::Feature
          end
        end


        # imports PrimitiveTypes
        module BehaviorialFeatures
          module BehavioralFeature
            include Classifiers::Feature
            include Namespaces::Namespace
          end

          module Parameter
            include TypedElements::TypedElement
            include Namespaces::NamedElement
          end # Parameter

          ruml :association, \
          nil,        BehavioralFeature, 0..1, { },
          :parameter, Parameter,         '*',  { :ordered => true, :subsets => :member, :union => true }
        end # BehaviorialFeatures

        module Changeabilities
          module StructuralFeature
            include BehaviorialFeatures::BehavioralFeature

            ruml :property, :isReadOnly, PrimitiveTypes::Boolean, 1, { :default => 'false' }
          end
        end # Changeabilities

        module Multiplicities
          # ruml :import, PrimitiveTypes

          module MultiplicityElement
            include Elements::Element

            ruml :property, :isOrdered, :Boolean, 1, { :default => 'false' }
            ruml :property, :isUnique, :Boolean, 1, { :default => 'true' }
            ruml :property, :lower,  :Integer, 0..1, { :default => '1' }
            ruml :property, :upper, :UnlimitedNatural, 0..1, { :default => '1' }

            def lowerBound
              lower.nil? ? 1 : lower
            end
            def upperBound
              upper.nil? ? 1 : upper
            end
            def isMultivalued
              upperBound > 1
            end
            def includesCardinality c
              lowerBound <= c || upperBound >= c
            end
            def includesMultiplicity m
              lowerBound <= m.lowerBound && upperBound >= m.upperBound
            end

          end
        end # Multiplicities


        module MultiplicityExpressions
        end # MultiplicityExpressions


        module Comments
          module Comment
            include Ownerships::Element

            ruml :property, :body, PrimitiveTypes::String
          end # Comment

          ruml :association, \
          :comment,          Comment,             :*, { },
          :annotatedElement, Ownerships::Element, :*, { }

          ruml :association, \
          :owningElement, Ownerships::Element, 0..1, { :subsets => :owner },
          :ownedComment,  Comment,             :*,   { :subsets => :ownedElement }
        end # Comments

        module Constraints
        end # Constraints
      end # ???


      module Basic
        ruml :import, \
        PrimitiveTypes,
        Abstractions::Namespaces,
        Abstractions::TypedElements,
        Abstractions::Multiplicities

        class Comment
          include RUML::Core::Runtime::Instantiable

          include Abstractions::Comments::Comment
        end

        class Class < Type
          include RUML::Core::Runtime::Instantiable

          include Type

          property :isAbstract, Boolean
        end

        class Property
          include RUML::Core::Runtime::Instantiable

          include TypedElement
          include MultiplicityElement

          ruml :property, :isReadOnly, Boolean
          ruml :property, :default, String, 0..1
          ruml :property, :isComposite, Boolean
          ruml :property, :isDerived, Boolean
        end


        class Operation
          include RUML::Core::Runtime::Instantiable

          include TypedElement
          include MultiplicityElement
        end

        class Parameter
          include RUML::Core::Runtime::Instantiable

          include TypedElement
          include MultiplicityElement
        end

        module DataType
          include Type
        end

        class PrimitiveType
          include RUML::Core::Runtime::Instantiable

          include DataType
        end

        class Enumeration
          include RUML::Core::Runtime::Instantiable

          include DataType
        end

        class EnumerationLiteral
          include RUML::Core::Runtime::Instantiable

          include NamedElement
        end

        class Package
          include RUML::Core::Runtime::Instantiable

          include NamedElement
        end


        ruml :association, \
        nil,         Class, :*, { :navigable => false },
        :superClass, Class, :*, { }

        ruml :association, \
        :class,          Class,    0..1, { :composition => true },
        :ownedAttribute, Property, :*,   { :ordered => true }

        ruml :association, \
        :opposite, Property, 0..1, { },
        nil,       Property, 0..1, { :navigable => false }

        ruml :association, \
        :class,          Class,     0..1, { :composition => true },
        :ownedOperation, Operation, :*,   { :ordered => true }

        ruml :association, \
        :operation,      Operation, 0..1, { :composition => true },
        :ownedParameter, Parameter, :*,   { :ordered => true }

        ruml :association, \
        nil,              Operation, 0..1, { :navigable => false },
        :raisedException, Type,      :*,   { }

        ruml :association, \
        :enumeration,    Enumeration,        0..1, { :composition => true },
        :ownedLiteral,   EnumerationLiteral, :*,   { :ordered => true }

        ruml :association, \
        :package, Package, 0..1, { :compostion => true },
        :ownedType, Type,  :*,   { }

        ruml :association, \
        :nestingPackage, Package, 0..1, { :compostion => true },
        :nestedPackage, Package,  :*,   { }

      end # Basic


      module Constructs
        import Abstractions

        module Type
          include TypedElements::Type
        end

        module PackageableElement
          include Namespaces::NamedElement
        end

        class Package
          include RUML::Core::Runtime::Instantiable

          include Namespaces::Namespace
          include PackageableElement
        end

        ruml :association, \
        :owningPackage,    Package,            0..1, { :subsets => :namespace, :aggregation => true },
        :packagedElement,  PackageableElement, :*,   { :subsets => :ownedMember }

        ruml :association, \
        :package,    Package, 0..1, { :subsets => :namespace, :aggregation => true },
        :ownedType,  Type,    :*,   { :subsets => :packagedElement }

        ruml :association, \
        :nestingPackage,   Package, 0..1, { :subsets => :namespace, :aggregation => true },
        :nestedPackage,    Package, :*,   { :subsets => :packagedElement }

        class Association
          include RUML::Core::Runtime::Instantiable

          include Namespaces::NamedElement
        end

        class AssociationEnd
          include RUML::Core::Runtime::Instantiable

          include Namespaces::NamedElement
        end
      end # Constructs

    end # Core

    module Profiles
    end # Profiles

  end

end # RUML
