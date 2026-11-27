# frozen_string_literal: true

require 'ruml/core'

module RUML::Core::Misc
  # !!! Use MOF::Reflection container?
  class UniqueArray < ::Array
    def push x
      super(x)
      uniq!(&:__id__)
      self
    end
    def << x ; push x; end
    def concat x
      super(x)
      uniq!(&:__id__)
      self
    end
  end
end
