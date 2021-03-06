require 'ruml/support'

module RUML

module UML
  module Core
    module PrimitiveTypes
      class Boolean
        include RUML::Support::Instantiable
        stereotype :primitive

        def self.coerce x
          case x
          when true, false
            x == true
          when Integer
            x != 0
          when :true, :false
            x == :true
          when 'true', 'false'
            x == 'true'
          when '1', '0'
            x != '0'
          else
            raise ArgumentError, "given #{self}"
          end
        end
      end

      class String
        include RUML::Support::Instantiable
        stereotype :primitive

        def self.coerce x
          x.to_s
        end
      end

      class Integer
        include RUML::Support::Instantiable
        stereotype :primitive

        def self.coerce x
          x.to_i
        end
      end

      class UnlimitedNatural < Integer
        include RUML::Support::Instantiable
        stereotype :primitive

        def initialize rep
          @rep = rep
        end

        INFINITY = new(:*) unless defined? INFINITY

        def to_s
          @rep.to_s
        end
        def inspect
          @rep.inspect
        end

        def >= x
          true
        end

        def <= x
          x != INFINITY
        end

        def > x
          x != INFINITY
        end

        def < x
          x != INFINITY
        end


        def self.coerce x
          case x
          when :*, '*'
            INFINITY
          else
            i = x.to_i
            raise ArgumentError, "not greater than zero" unless i > 0
            i
          end
        end
      end

    end # PrimitiveTypes


    module Abstractions

      module Elements
        module Element
        end
      end # Elements

      module Ownerships
        module Element
          include Elements::Element
        end 

        association \
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

        association \
        nil,             Relationship,        :*,     { :navigable => false },
        :relatedElement, Ownerships::Element, '1..N', { :readOnly => true, :union => true }

        association \
        nil,     Relationship,        :*,     { :navigable => false },
        :source, Ownerships::Element, '1..N', { :subsets => :relatedElement, :readOnly => true, :union => true }

        association \
        nil,     Relationship,        :*,     { :navigable => false },
        :target, Ownerships::Element, '1..N', { :subsets => :relatedElement, :readOnly => true, :union => true }

      end # Relationships


      module Namespaces
        module NamedElement
          include Ownerships::Element
          
          property :name, PrimitiveTypes::String
          
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

        association \
        :namespace,   Namespace,     0..1, { :readOnly => true, :union => true, :subsets => :owner,  },
        :ownedMember, NamedElement,  :*, { :readOnly => true, :union => true, :subsets => [ :member, :ownedElement ], }
        
        association \
        :owner,       Namespace,     :*, { :navigable => false },
        :member,      NamedElement,  :*, { :readOnly => true, :union => true, }

      end # Namespaces

      
      module Expressions
        module ValueSpecification
          include Ownerships::Element
        end

        class OpaqueExpression
          include RUML::Support::Instantiable
          include ValueSpecification
          property :body, String, :*, { :ordered => true }
          property :language, String, :*, { :ordered => true }
        end

        class Expression
          include RUML::Support::Instantiable
          include ValueSpecification
          property :symbol, String
        end

        association \
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

        association \
        :featuringClassifier, Classifier, :*, { },
        :feature,             Feature,    :*, { :subsets => :member, :union => true }
      end # Classifiers


      module TypedElements
        module Type
          include Namespaces::NamedElement
        end # Type

        module TypedElement
          include Namespaces::NamedElement
        end # TypedElement

        association \
        nil, TypedElement, :*, { :navigable => false },
        :type, Type, 0..1, { }
      end # TypedElements


      module StructuralFeatures
        module StructuralFeature
          include TypedElements::TypedElement
          include Classifiers::Feature
        end
      end # StructuralFeatures


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

        association \
        nil,        BehavioralFeature, 0..1, { },
        :parameter, Parameter,         '*',  { :ordered => true, :subsets => :member, :union => true }
      end # BehaviorialFeatures

      module Changeabilities
        module StructuralFeature
          include BehaviorialFeatures::BehavioralFeature
        
          property :isReadOnly, PrimitiveTypes::Boolean, 1, { :default => 'false' }
        end
      end # Changeabilities

      module Multiplicities
        import PrimitiveTypes

        module MultiplicityElement
          include Elements::Element

          property :isOrdered, Boolean, 1, { :default => 'false' }
          property :isUnique, Boolean, 1, { :default => 'true' }
          property :lower,  Integer, 0..1, { :default => '1' }
          property :upper, UnlimitedNatural, 0..1, { :default => '1' }

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

          property :body, PrimitiveTypes::String
        end # Comment

        association \
        :comment,          Comment,             :*, { },
        :annotatedElement, Ownerships::Element, :*, { }

        association \
        :owningElement, Ownerships::Element, 0..1, { :subsets => :owner },
        :ownedComment,  Comment,             :*,   { :subsets => :ownedElement }
      end # Comments

      module Constraints
      end # Constraints


    end # ???


    module Basic
      import \
      PrimitiveTypes, 
      Abstractions::Namespaces, 
      Abstractions::TypedElements,
      Abstractions::Multiplicities
      
      class Comment
        include RUML::Support::Instantiable

        include Abstractions::Comments::Comment
      end

      class Class
        include RUML::Support::Instantiable

        include Type

        property :isAbstract, Boolean
      end

      class Property
        include RUML::Support::Instantiable

        include TypedElement
        include MultiplicityElement

        property :isReadOnly, Boolean
        property :default, String, 0..1
        property :isComposite, Boolean
        property :isDerived, Boolean
      end


      class Operation
        include RUML::Support::Instantiable

        include TypedElement
        include MultiplicityElement
      end

      class Parameter
        include RUML::Support::Instantiable

        include TypedElement
        include MultiplicityElement
      end

      module DataType
        include Type
      end
      
      class PrimitiveType
        include RUML::Support::Instantiable

        include DataType
      end

      class Enumeration
        include RUML::Support::Instantiable

        include DataType
      end

      class EnumerationLiteral
        include RUML::Support::Instantiable

        include NamedElement
      end

      class Package
        include RUML::Support::Instantiable

        include NamedElement
      end


      association \
      nil,         Class, :*, { :navigable => false },
      :superClass, Class, :*, { }

      association \
      :class,          Class,    0..1, { :composition => true },
      :ownedAttribute, Property, :*,   { :ordered => true }

      association \
      :opposite, Property, 0..1, { },
      nil,       Property, 0..1, { :navigable => false }

      association \
      :class,          Class,     0..1, { :composition => true },
      :ownedOperation, Operation, :*,   { :ordered => true }

      association \
      :operation,      Operation, 0..1, { :composition => true },
      :ownedParameter, Parameter, :*,   { :ordered => true }

      association \
      nil,              Operation, 0..1, { :navigable => false },
      :raisedException, Type,      :*,   { }

      association \
      :enumeration,    Enumeration,        0..1, { :composition => true },
      :ownedLiteral,   EnumerationLiteral, :*,   { :ordered => true }

      association \
      :package, Package, 0..1, { :compostion => true },
      :ownedType, Type,  :*,   { }

      association \
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
        include RUML::Support::Instantiable
        
        include Namespaces::Namespace
        include PackageableElement
      end

      association \
      :owningPackage,    Package,            0..1, { :subsets => :namespace, :aggregation => true },
      :packagedElement,  PackageableElement, :*,   { :subsets => :ownedMember }

      association \
      :package,    Package, 0..1, { :subsets => :namespace, :aggregation => true },
      :ownedType,  Type,    :*,   { :subsets => :packagedElement }

      association \
      :nestingPackage,   Package, 0..1, { :subsets => :namespace, :aggregation => true },
      :nestedPackage,    Package, :*,   { :subsets => :packagedElement }

      class Association
        include RUML::Support::Instantiable
        
        include Namespaces::NamedElement
      end
      
      class AssociationEnd
        include RUML::Support::Instantiable
        
        include Namespaces::NamedElement
      end
    end # Constructs
    
  end # Core

  module Profiles
  end # Profiles

end # UML

end # RUML

