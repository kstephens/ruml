require 'ruml/support'
require 'ruml/builder'

module RUML
  module UML2
    RUML::Builder.new(:target => self) do
      package :Core do
        package :PrimitiveTypes do
          _class :Boolean do
            stereotype :primitive

            method :coerce, :class do | x |
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
          end # Boolean

          _class :String do
            stereotype :primitive

            method :coerce, :class do | x |
              x.to_s
            end
          end # String

          _class :Integer do
            stereotype :primitive

            method :coerce, :class do | x |
              x.to_i
            end
          end # Integer

          _class :UnlimitedNatural, :Integer do 
            stereotype :primitive

            method :initialize do | rep |
              @rep = rep
            end

            constant(:INFINITY) { new(:*) }

            method :to_s do
              @rep.to_s
            end
            method :inspect do
              @rep.inspect
            end

            method :>= do | x |
              true
            end

            method :<= do | x |
              x != self.INFINITY
            end

            method :> do | x |
              x != self.INFINITY
            end

            method :< do | x |
              x != self.INFINITY
            end

            method :coerce, :class do | x |
              $stderr.puts "#{self}.coerce #{x.inspect}"
              case x
              when :*, '*'
                self.INFINITY
              else
                i = x.to_i
                raise ArgumentError, "not greater than zero" unless i > 0
                i
              end
            end
          end # 

        end # PrimitiveTypes

=begin
    package :Abstractions

      package :Elements do
        _class :Element do
          isAbstract true # ???
        end
      end # Elements

      package :Ownerships do
        _class :Element do
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
        _class :Relationship do
          isAbstract true # ???
          generalization 'Ownerships::Element'
        end

        _class :DirectedRelationship do
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
        _class :NamedElement do
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
        
        _class :Namespace
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
        _class :ValueSpecification do
          isAbstract true # ???
          generalization 'Ownerships::Element'
        end

        _class :OpaqueExpression do
          generalization :ValueSpecification
          property :body, :String, :*, { :ordered => true }
          property :language, :String, :*, { :ordered => true }
        end

        _class :Expression do
          generalization :ValueSpecification
          property :symbol, :String
        end

        association \
        :expression, :Expression,         0..1, { :subsets => :owner, :aggregation => true },
        :operand,    :ValueSpecification, :*,   { :subsets => :ownedElement, :ordered => true }        
      end # Expressions


      package :Classifiers do
        _class :Classifier
          isAbstract true # ???
          generalization 'Namespaces::Namespace'
        end # Classifier

        _class :Feature do
          isAbstract true # ???
          generalization 'Namespaces::NamedElement'
        end # Feature

        association \
        :featuringClassifier, :Classifier, :*, { },
        :feature,             :Feature,    :*, { :subsets => :member, :union => true }
      end # Classifiers


      package :TypedElements do
        _class :Type do
          isAbstract true # ???
          generalization 'Namespaces::NamedElement'
        end # Type

        _class :TypedElement do
          isAbstract true # ???
          generalization 'Namespaces::NamedElement'
        end # TypedElement

        association \
        nil,   :TypedElement, :*, { :navigable => false },
        :type, :Type, 0..1, { }
      end # TypedElements


      package :StructuralFeatures do
        _class :StructuralFeature do
          isAbstract true # ???
          generalization 'TypedElements::TypedElement', 'Classifiers::Feature'
        end
      end # StructuralFeatures


      # imports PrimitiveTypes
      package :BehaviorialFeatures do
        _class :BehavioralFeature do
          isAbstract true # ???
          generalization 'Classifiers::Feature', 'Namespaces::Namespace'
        end
        
        _class :Parameter do
          generalization 'TypedElements::TypedElement', 'Namespaces::NamedElement'
        end # Parameter

        association \
        nil,        :BehavioralFeature, 0..1, { },
        :parameter, :Parameter,         '*',  { :ordered => true, :subsets => :member, :union => true }
      end # BehaviorialFeatures

      package :Changeabilities do
        _class :StructuralFeature do
          isAbstract true # ???
          generalization 'BehaviorialFeatures::BehavioralFeature'
        
          property :isReadOnly, 'PrimitiveTypes::Boolean', 1, { :default => 'false' }
        end
      end # Changeabilities

      package :Multiplicities do
        import :PrimitiveTypes 

        _class :MultiplicityElement do
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
        _class :Comment
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
      
      _class :Comment do
        generalization 'Abstractions::Comments::Comment'
      end

      _class :Class do
        generalization :Type

        property :isAbstract, :Boolean
      end

      _class :Property do
        generalization :TypedElement, :MultiplicityElement

        property :isReadOnly,  :Boolean
        property :default,     :String, 0..1
        property :isComposite, :Boolean
        property :isDerived,   :Boolean
      end


      _class :Operation do
        generalization :TypedElement, :MultiplicityElement
      end

      _class :Parameter do
        generalization :TypedElement, :MultiplicityElement
      end

      _class :DataType do
        isAbstract true
        generalization :Type
      end
      
      _class :PrimitiveType do
        generalization :DataType
      end

      _class :Enumeration do
        generalization :DataType
      end

      _class :EnumerationLiteral do
        generalization :NamedElement
      end

      _class :Package do
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

      _class :Type do
        isAbstract true # ???
        generalization 'TypedElements::Type'
      end

      _class :PackageableElement do
        isAbstract true # ???
        generalization 'Namespaces::NamedElement'
      end

      _class :Package do
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

      _class :Association do
        generalization 'Namespaces::NamedElement'
      end
      
      _class AssociationEnd do
        generalization 'Namespaces::NamedElement'
      end
    end # Constructs
=end

      end # Core


      package :Profiles do
      end # Profiles

    end.compile(:language => :ruby, :target => RUML::UML2) # Builder.new

  end # UML2
end # RUML


