# frozen_string_literal: true

require 'ruml/runtime'
require 'ruml/builder'

module RUML
  UNLIMITED = 12345678901234567890

  module PrimitiveTypes
    def initialize repr
      @_repr_ = repr
    end
    def self.to_native type, value
      type._coerce_to_native(value)
    end
  end

  module UML2

    RUML::Builder.new(target: self) do
      package :Core do
        package :PrimitiveTypes do
          class_ :Boolean do
            include PrimitiveTypes
            stereotype :primitive

            coercions = {
              nil => false,
              0 => false,
              1 => true,
              true => true,
              false => false,
              :true   => true,
              :false  => false,
              'true'  => true,
              'false' => false,
              '1'     => true,
              '0'     => false,
            }

            operation :_coerce_to_native, :class do | x |
              case x
              when ::Integer, ::Float then x != 0
              else
                val = coercions[x]
                raise ArgumentError, "coerce : #{self} : given #{x.inspect}" if val.nil?
              end
            end
          end # Boolean

          class_ :String do
            include PrimitiveTypes
            stereotype :primitive

            operation :to_i do @_repr_.to_i end

              operation :_coerce_to_native, :class do | x |
              x.to_s
            end
          end # String

          class_ :Integer do
            include PrimitiveTypes
            stereotype :primitive

            operation :initialize do | rep |
              @rep = rep
            end

            operation :to_i do @_repr_.to_i end

            operation :_coerce_to_native, :class do | x |
              x.to_i
            end
          end # Integer

          class_ :UnlimitedNatural, :Integer do
            include PrimitiveTypes
            stereotype :primitive

            operation :to_i do @_repr_.to_i end

            operation :_coerce_to_native, :class do | x |
              case x
              when :*, '*'
                UNLIMITED
              else
                i = x.to_i
                raise ArgumentError, "not >= 0" unless i >= 0
                i
              end
            end

            operation :unlimited, :class do
              @unlimited ||= new(UNLIMITED)
            end
          end
        end # PrimitiveTypes
      end
    end
    .tap{|b| ::RUML::AST::Printer.new().call(b.root)}
    ._compile(language: :ruby)
  end
end

=begin
    package :Abstractions

      package :Elements do
        class_ :Element do
          isAbstract true # ???
        end
      end # Elements

      package :Ownerships do
        class_ :Element do
          isAbstract true # ???
          generalization 'Elements::Element'
        end

        association \
        :owner,        Element, 0..1, { :aggregation => true, :union => true },
        :ownedElement, Element, :*,   { :union => true }

        method :allOwnedElements do
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

        method :mustBeOwned do
          true
        end
      end # Ownerships


      package :Relationships do
        class_ :Relationship do
          isAbstract true # ???
          generalization 'Ownerships::Element'
        end

        class_ :DirectedRelationship do
          isAbstract true # ???
          generalization :Relationship
        end

        association \
        nil,             :Relationship,        :*,     { :navigable => false },
        :relatedElement, 'Ownerships::Element', '1..N', { :readOnly => true, :union => true }

        association \
        nil,     :Relationship,        :*,      { :navigable => false },
        :source, 'Ownerships::Element', '1..N', { :subsets => :relatedElement, :readOnly => true, :union => true }

        association \
        nil,     :Relationship,        :*,     { :navigable => false },
        :target, 'Ownerships::Element', '1..N', { :subsets => :relatedElement, :readOnly => true, :union => true }

      end # Relationships


      package :Namespaces do
        class_ :NamedElement do
          isAbstract true # ???
          generalization 'Ownerships::Element'

          property :name, 'PrimitiveTypes::String'

          method :qualifiedName do
            allNamespaces.join(separator)
          end

          SEPARATOR = '::'.freeze unless defined? SEPARATOR
          method :separator do
            SEPARATOR
          end

          method :inspect do
            "\#<#{self.class} #{name.inspect} ...>"
          end
        end

        class_ :Namespace
          isAbstract true # ???
          generalization :NamedElement
        end

        association \
        :namespace,   Namespace,     0..1, { :readOnly => true, :union => true, :subsets => :owner,  },
        :ownedMember, NamedElement,  :*, { :readOnly => true, :union => true, :subsets => [ :member, :ownedElement ], }

        association \
        :owner,       Namespace,     :*, { :navigable => false },
        :member,      NamedElement,  :*, { :readOnly => true, :union => true, }

      end # Namespaces


      package :Expressions do
        class_ :ValueSpecification do
          isAbstract true # ???
          generalization 'Ownerships::Element'
        end

        class_ :OpaqueExpression do
          generalization :ValueSpecification
          property :body, :String, :*, { :ordered => true }
          property :language, :String, :*, { :ordered => true }
        end

        class_ :Expression do
          generalization :ValueSpecification
          property :symbol, :String
        end

        association \
        :expression, :Expression,         0..1, { :subsets => :owner, :aggregation => true },
        :operand,    :ValueSpecification, :*,   { :subsets => :ownedElement, :ordered => true }
      end # Expressions


      package :Classifiers do
        class_ :Classifier
          isAbstract true # ???
          generalization 'Namespaces::Namespace'
        end # Classifier

        class_ :Feature do
          isAbstract true # ???
          generalization 'Namespaces::NamedElement'
        end # Feature

        association \
        :featuringClassifier, :Classifier, :*, { },
        :feature,             :Feature,    :*, { :subsets => :member, :union => true }
      end # Classifiers


      package :TypedElements do
        class_ :Type do
          isAbstract true # ???
          generalization 'Namespaces::NamedElement'
        end # Type

        class_ :TypedElement do
          isAbstract true # ???
          generalization 'Namespaces::NamedElement'
        end # TypedElement

        association \
        nil,   :TypedElement, :*, { :navigable => false },
        :type, :Type, 0..1, { }
      end # TypedElements


      package :StructuralFeatures do
        class_ :StructuralFeature do
          isAbstract true # ???
          generalization 'TypedElements::TypedElement', 'Classifiers::Feature'
        end
      end # StructuralFeatures


      # imports PrimitiveTypes
      package :BehaviorialFeatures do
        class_ :BehavioralFeature do
          isAbstract true # ???
          generalization 'Classifiers::Feature', 'Namespaces::Namespace'
        end

        class_ :Parameter do
          generalization 'TypedElements::TypedElement', 'Namespaces::NamedElement'
        end # Parameter

        association \
        nil,        :BehavioralFeature, 0..1, { },
        :parameter, :Parameter,         '*',  { :ordered => true, :subsets => :member, :union => true }
      end # BehaviorialFeatures

      package :Changeabilities do
        class_ :StructuralFeature do
          isAbstract true # ???
          generalization 'BehaviorialFeatures::BehavioralFeature'

          property :isReadOnly, 'PrimitiveTypes::Boolean', 1, { :default => 'false' }
        end
      end # Changeabilities

      package :Multiplicities do
        import :PrimitiveTypes

        class_ :MultiplicityElement do
          isAbstract true # ???
          generalization 'Elements::Element'

          property :isOrdered, :Boolean, 1, { :default => 'false' }
          property :isUnique, :Boolean, 1, { :default => 'true' }
          property :lower,  :Integer, 0..1, { :default => '1' }
          property :upper, :UnlimitedNatural, 0..1, { :default => '1' }

          method :lowerBound do
            lower.nil? ? 1 : lower
          end
          method :upperBound do
            upper.nil? ? 1 : upper
          end
          method :isMultivalued do
            upperBound > 1
          end
          method :includesCardinality do | c |
            lowerBound <= c || upperBound >= c
          end
          method :includesMultiplicity do | m |
            lowerBound <= m.lowerBound && upperBound >= m.upperBound
          end

        end
      end # Multiplicities


      package :MultiplicityExpressions do
      end # MultiplicityExpressions


      package :Comments do
        class_ :Comment
          generalization 'Ownerships::Element'

          property :body, 'PrimitiveTypes::String'
        end # Comment

        association \
        :comment,          :Comment,             :*, { },
        :annotatedElement, 'Ownerships::Element', :*, { }

        association \
        :owningElement, 'Ownerships::Element', 0..1, { :subsets => :owner },
        :ownedComment,  :Comment,             :*,   { :subsets => :ownedElement }
      end # Comments

      package :Constraints do
      end # Constraints


    end # ???


    package :Basic do
      import \
      :PrimitiveTypes,
      'Abstractions::Namespaces',
      'Abstractions::TypedElements',
      'Abstractions::Multiplicities'

      class_ :Comment do
        generalization 'Abstractions::Comments::Comment'
      end

      class_ :Class do
        generalization :Type

        property :isAbstract, :Boolean
      end

      class_ :Property do
        generalization :TypedElement, :MultiplicityElement

        property :isReadOnly,  :Boolean
        property :default,     :String, 0..1
        property :isComposite, :Boolean
        property :isDerived,   :Boolean
      end


      class_ :Operation do
        generalization :TypedElement, :MultiplicityElement
      end

      class_ :Parameter do
        generalization :TypedElement, :MultiplicityElement
      end

      class_ :DataType do
        isAbstract true
        generalization :Type
      end

      class_ :PrimitiveType do
        generalization :DataType
      end

      class_ :Enumeration do
        generalization :DataType
      end

      class_ :EnumerationLiteral do
        generalization :NamedElement
      end

      class_ :Package do
        generalization :NamedElement
      end


      association \
      nil,         :Class, :*, { :navigable => false },
      :superClass, :Class, :*, { }

      association \
      :class,          :Class,    0..1, { :composition => true },
      :ownedAttribute, :Property, :*,   { :ordered => true }

      association \
      :opposite, :Property, 0..1, { },
      nil,       :Property, 0..1, { :navigable => false }

      association \
      :class,          :Class,     0..1, { :composition => true },
      :ownedOperation, :Operation, :*,   { :ordered => true }

      association \
      :operation,      :Operation, 0..1, { :composition => true },
      :ownedParameter, :Parameter, :*,   { :ordered => true }

      association \
      nil,              :Operation, 0..1, { :navigable => false },
      :raisedException, :Type,      :*,   { }

      association \
      :enumeration,    :Enumeration,        0..1, { :composition => true },
      :ownedLiteral,   :EnumerationLiteral, :*,   { :ordered => true }

      association \
      :package, :Package, 0..1, { :compostion => true },
      :ownedType, :Type,  :*,   { }

      association \
      :nestingPackage, :Package, 0..1, { :compostion => true },
      :nestedPackage,  :Package,  :*,   { }

    end # Basic


    package :Constructs do
      import :Abstractions

      class_ :Type do
        isAbstract true # ???
        generalization 'TypedElements::Type'
      end

      class_ :PackageableElement do
        isAbstract true # ???
        generalization 'Namespaces::NamedElement'
      end

      class_ :Package do
        generalization 'Namespaces::Namespace', 'PackageableElement'
      end

      association \
      :owningPackage,    :Package,            0..1, { :subsets => :namespace, :aggregation => true },
      :packagedElement,  :PackageableElement, :*,   { :subsets => :ownedMember }

      association \
      :package,    :Package, 0..1, { :subsets => :namespace, :aggregation => true },
      :ownedType,  :Type,    :*,   { :subsets => :packagedElement }

      association \
      :nestingPackage,   :Package, 0..1, { :subsets => :namespace, :aggregation => true },
      :nestedPackage,    :Package, :*,   { :subsets => :packagedElement }

      class_ :Association do
        generalization 'Namespaces::NamedElement'
      end

      class_ AssociationEnd do
        generalization 'Namespaces::NamedElement'
      end
    end # Constructs

      end # Core


      package :Profiles do
      end # Profiles
    end
  end # UML2
end # RUML

=end
