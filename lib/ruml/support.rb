
require 'ruml'

module RUML
  module Support
    def self.copy_method(dst,dst_name, src_module, src_name = dst_name)
      dst.define_method(dst_name, src_module.instance_method(src_name))
    end
  end
end
