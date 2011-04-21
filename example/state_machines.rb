
require 'ruml/support'
require 'ruml/builder'

module MyTest
  RUML::Builder.new(:verbose => true) do
    package :MyPackage do
      _class :NamedElement, :isAbstract => true do
        property :name, String
      end
      
      _class :Namespace, :isAbstract => true do
        generalization :NamedElement
        
        association \
        :namespace,   :Namespace, 0..1, { },
        :ownedMember, :NamedElement, :*, { }
      end

      _class :Region do
        generalization :Namespace
      end

      _class :Vertex, :isAbstract => true do
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

      _class :State do
        generalization :Namespace
        property :isComposite, :Boolean # false { readOnly }
        property :isOrthogonal, :Boolean # false { readOnly }
        property :isSimple, :Boolean # = true { readOnly }
        property :isSubmachineState, :Boolean # = false { readOnly }
      end

      _class :Transition do
        generalization :Namespace
        property :kind, :TransitionKind # = external
        association \
        :transition, :Transition, :*, { :subsets => :ownedMember },
        :container,  :Region,      1, { :subsets => :namespace }
      end

    end
  end.compile(:target => self, :verbose => true)

end

