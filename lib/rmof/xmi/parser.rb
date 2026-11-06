# frozen_string_literal: true
require 'rmof'
require 'rmof/xmi'
require 'rmof/xmi/factory'
require 'rmof/xmi/resolver'
require 'nokogiri'
require 'uri'
require 'typhoeus'

module RMOF
  module XMI
    class Parser
      attr_accessor :parsers
      attr_reader :factory

      def initialize
        @doms = { }
        @contents = { }
        @href = { }
        @redirects = {
          "http://www.omg.org/spec/UML/20131001/PrimitiveTypes.xmi" =>
          "http://www.omg.org/spec/UML/20161101/PrimitiveTypes.xmi",
        }
        @factory = Factory.new
      end

      def call(xmi)
        parser = ParserCore.new(self)
        parser.call(xmi).root
      end

      def load_xml(xmi)
        @doms[xmi] ||= parse_xml(xmi)
      end

      def parse_xml(xmi)
        content = self.content(xmi)
        Nokogiri::XML(content) do |config|
          config.noblanks
        end
      end

      def content(xmi)
        @contents[xmi] ||= fetch_content(xmi)
      end

      def fetch_content(url)
        url = @redirects[url] || url
        if File.exist?(url)
          $stderr.puts "Reading #{url.inspect}"
          return File.read(url)
        end
        uri = URI.parse(url)
        local_file = "vendor/#{uri.host}#{uri.path}"
        if File.exist?(local_file)
          $stderr.puts "Reading #{local_file.inspect}"
          File.read(local_file)
        else
          # binding.pry
          $stderr.puts "GET #{url.inspect}"
          Typhoeus.get(url).body
        end
      end

      def resolve_href href
        @href[href] ||= find_href(href)
      end

      def find_href href
        @verbose = true
        url = URI.parse(href)
        xmi_id = url.fragment
        url.fragment = nil
        location = url.to_s
        log { "href=#{href.inspect}" }
        log { "location=#{location.inspect} xmi_id=#{xmi_id.inspect}" }
        dom = load_xml(location)
        xmlns_xmi = dom.namespaces["xmlns:xmi"]
        ns_map = {"xmi" => xmlns_xmi}
        xpath = "//*[@xmi:id=#{xmi_id.inspect}]"
        log { "dom.namespaces=#{dom.namespaces.inspect}" }
        log { "ns_map=#{ns_map.inspect}" }
        log { "xpath=#{xpath.inspect}" }
        binding.pry unless ns_map["xmi"]
        elem = dom.at_xpath(xpath, ns_map)
        binding.pry unless elem
        @verbose = false
        raise StandardError, "cannot resolve href=#{href.inspect} at #{xpath.inspect}" unless elem
        elem
      end

      def log msg=nil
        if @verbose
          msg ||= yield
          $stderr.puts "### #{self.class.name} # #{msg}"
        end
      end
    end

    class ParserCore
      attr_accessor :top_level, :dom, :root

      def factory
        @top_level.factory
      end

      def initialize top_level
        @top_level = top_level
        @root = factory.get_xmi_type("xmi", "XMI").new
        @hrefs = {}
        @elem_stack = []
        @target_stack = []
        @xmi_id_to_object = {}
      end

      def call(xmi_url)
        xmi_url = xmi_url.to_s
        @xmi_url = xmi_url
        @dom = @top_level.load_xml(xmi_url)
        @target_stack.push(@root)
        @phase = :build
        parse_doc(@dom)
        @phase = :resolve
        parse_doc(@dom)
        binding.pry
        self
      end

      def parse_doc(elem)
        elem.children[0].children.each do | e |
          next if e.name == "documentation"
          parse(e)
        end
      end

      def parse_children(elem)
        elem.children.each{|e| parse(e) }
      end

      def parse(elem)
        _parse(elem)
      rescue StandardError => e
        elem = elem.dup
        elem.children.remove
        raise e, "#{e.message} : at line #{elem.line} : #{elem.to_xml}", e.backtrace
        #  binding.pry
      end

      def _parse(elem)
        log { "### ######################################################" }
        log { "ELEM  : #{elem.name} @#{elem.object_id}" }
        log { "ATTRS : #{convert_attrs(elem).inspect}" }
        parent = @target_stack.last
        @elem_stack.push(elem)
        begin
          xmi_type = get_attr(elem, 'xmi', 'type')&.value
          xmi_id = get_attr(elem, 'xmi', 'id')&.value
          xmi_idref = get_attr(elem, 'xmi', 'idref')&.value
          href = get_attr(elem, nil, 'href')&.value
          unique_id = xmi_id || xmi_idref
          unique_id &&= "#{@xmi_url}\##{unique_id}"
          case
          when xmi_idref
            if xmi_type || xmi_id
              raise StandardError, "has idref #{xmi_idref.inspect} and xmi_type #{xmi_type.inspect} xmi_id #{xmi_id.inspect}"
            end
            obj = @xmi_id_to_object[xmi_idref]
            case
            when @phase == :resolve
              unless obj
                raise StandardError, "unknown idref #{xmi_idref.inspect}"
              end
            end
          when xmi_type
            # binding.pry
            xmi_type_prefix, xmi_type_name = xmi_type.split(':', 2)
            properties = {}
            get_attr(elem, nil, nil) do | attr |
              properties[attr.name] = attr.value
            end
            obj = factory.make_instance(xmi_type_prefix, xmi_type_name, properties, unique_id)
            obj._xmi.type = xmi_type
            obj._xmi.id = xmi_id
            obj._xmi.type_prefix = xmi_type_prefix
            obj._xmi.type_name = xmi_type_name
            obj._xmi.url = @xmi_url
            obj._xmi.line = elem.line
            @xmi_id_to_object[xmi_id] = obj if xmi_id
            log { "PROPERTIES : #{properties.inspect}" }
            log { "OBJECT     : #{obj.inspect}" }
          when href
            if @phase == :build
              dom = @top_level.resolve_href(href)
              other = parse(dom)
              attr = elem.name.to_sym
              parent._xmi.associations[attr].push(other)
              log { "parent=#{parent}" }
              log { "attr=#{attr.inspect}" }
              log { "prop=#{parent.__send__(attr)}" }
              # binding.pry
            end
          when elem.attributes.empty?
            parent.__send__(:"#{elem.name}=", elem.content)
          else
            raise StandardError, "no xmi:type or xmi:idref"
          end

          if obj
            @target_stack.push(obj)
            begin
              if @phase == :resolve and obj and parent
                log { "  obj=#{obj}" }
                log { "  parent=#{parent}" }
                attr = elem.name.to_sym
                parent._xmi.associations[attr].push(obj)
                log { "  associations: #{parent._xmi.associations.keys.inspect}" }
              end
              parse_children(elem)
            ensure
              @target_stack.pop
            end
          end

          obj
        ensure
          @elem_stack.pop
        end
      end

      def convert_attrs(elem)
        attrs = {}
        elem.attribute_nodes.each do | attr |
          name = attr.name
          if prefix = attr.namespace&.prefix
            name = "#{prefix}:#{name}"
          end
          attrs[name] = attr.value
        end
        attrs
      end

      def get_attr(elem, prefix, name)
        elem.attribute_nodes.each do | attr |
          next if name && name != attr.name
          next if prefix.nil? && attr.namespace&.prefix
          next if prefix && prefix != attr.namespace&.prefix
          if block_given?
            yield attr
          else
            return attr
          end
        end
        nil
      end

      def log msg=nil
        if @verbose
          msg ||= yield
          $stderr.puts "### #{self.class.name} # #{msg}"
        end
      end
    end
  end
end

