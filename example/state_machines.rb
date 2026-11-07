# frozen_string_literal: true

require 'ruml/support'
require 'ruml/builder'

module MyTest
  RUML::Builder.new(:verbose => true) do
    package :MyPackage do
      class_ :NamedElement, :isAbstract => true do
        property :name, String
      end

      class_ :Namespace, :isAbstract => true do
        generalization :NamedElement

        association \
        :namespace,   :Namespace, 0..1, { },
        :ownedMember, :NamedElement, :*, { }
      end

      class_ :Region do
        generalization :Namespace
      end

      class_ :Vertex, :isAbstract => true do
        generalization :NamedElement
        association \
        :subvertex, :Vertex, :*,   { :subsets => :ownedMember },
        :container, :Region, 0..1, { :subsets => :namespace }
        association \
        :source, :Vertex, 1, { },
        :outgoing, :Transition, :*
        association \
        :target, :Vertex, 1, { },
        :incoming, :Transition, :*
      end

      class_ :State do
        generalization :Namespace
        property :isComposite, :Boolean # false { readOnly }
        property :isOrthogonal, :Boolean # false { readOnly }
        property :isSimple, :Boolean # = true { readOnly }
        property :isSubmachineState, :Boolean # = false { readOnly }
      end

      class_ :Transition do
        generalization :Namespace
        property :kind, :TransitionKind # = external
        association \
        :transition, :Transition, :*, { :subsets => :ownedMember },
        :container,  :Region,      1, { :subsets => :namespace }
      end

    end
  end.compile(:target => self, :verbose => true)

end

