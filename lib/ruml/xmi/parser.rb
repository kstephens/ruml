# frozen_string_literal: true

require 'ruml'
require 'ruml/xmi'
require 'ruml/support/logging'
# require 'ruml/core/misc'
require 'nokogiri'
require 'uri'
require 'faraday'
require "forwardable"
require "set"

module RUML
  module XMI
    class ParserError < ::RUML::Error
      attr_accessor :reason, :data
      def initialize msg=nil, reason=nil, data=nil
        @reason, @data = reason, data
        super(msg || reason&.inspect || "NO-MESSAGE")
      end
    end

    class Parser
      extend Forwardable
      include RUML::Support::Logging::Basic
      attr_accessor :parsers
      attr_reader :factory, :stats, :errors
      attr_reader :documentation
      attr_accessor :continue_after_error

      def initialize factory: nil, **opts
        logger.level = Logger::INFO
        @factory = factory or raise ArgumentError, "expected factory"
        @continue_after_error = opts.fetch(:continue_after_error, true)
        @doms = { }
        @contents = { }
        @href = { }
        @redirects = {
          # "https://www.omg.org/spec/UML/20131001/UML.xmi" =>
          # "https://www.omg.org/spec/UML/20161101/UML.xmi",
          # "https://www.omg.org/spec/UML/20131001/PrimitiveTypes.xmi" =>
          # "https://www.omg.org/spec/UML/20161101/PrimitiveTypes.xmi",
        }
        @errors = []
        @documentation = Hash.new {|h, url| h[url] = Set.new}
        @stats = Hash.new do | h, n |
          h[n] = Hash.new do | h, k |
            h[k] = 0
          end
        end
      end

      def call(url)
        @url = @root_url = url
        @root_parser = ParserCore.new(self)
        begin
          @root_parser.call(url)
        ensure
          log_errors unless @errors.empty?
        end
        @root_parser.root_obj
      end

      def urls ; @doms.keys ; end

      def log_errors
        @errors.each do |error|
          e = error.reason
          puts "#####################################################"
          puts("#E! : #{error.inspect} : #{e.inspect}")
          error.data.each do | kind, items |
            items.each_with_index() do | item, index |
              puts "#E! : #{kind} : #{"%3d" % index} : #{item}"
            end
          end
          e.backtrace.each_with_index() do | item, index |
            next if item =~ %r{/rspec|/bundler/}
            puts "#E! : at : #{"%3d" % index} #{item}"
          end
        end
      end

      def_delegators :@root_parser, :url, :root_obj, :dom
      def root ; @root_parser&.root_obj ; end

      def load_xml(url)
        @doms[url] ||= parse_xml(url)
      end

      def parse_xml(url)
        content = self.content(url)
        Nokogiri::XML(content) do |config|
          config.noblanks
        end
      end

      def content(url)
        @contents[url] ||= fetch_content(url)
      end

      def fetch_content(url)
        log { "fetch_content #{url.inspect}" }
        url = url.sub('http://www.omg.org/', 'https://www.omg.org/')
        url = @redirects[url] || url
        # binding.pry
        if File.exist?(url)
          log { "fetch_content: Reading #{url.inspect}" }
          return File.read(url)
        end
        uri = URI.parse(url)
        local_file = "vendor/#{uri.host}#{uri.path}"
        if File.exist?(local_file)
          log { "fetch_content: Reading #{local_file.inspect} for #{url.inspect}" }
          File.read(local_file)
        else
          log { "fetch_content: GET #{url.inspect}" }
          response = Faraday.get(url)
          raise ParserError, "GET #{url.inspect} failed : #{response.status}" if response.status != 200
          response.body
        end
      end

      def resolve_href href
        @href[href] ||= find_href(href)
      end

      def find_href href
        url = URI.parse(href)
        xmi_id, url.fragment = url.fragment, nil
        location = url.to_s
        log { "find_href(#{href.inspect})" }
        logger.debug { "find_href location=#{location.inspect} xmi_id=#{xmi_id.inspect}" }
        dom = load_xml(location)
        logger.debug { "dom.namespaces=#{dom.namespaces.inspect}" }
        xmlns_xmi = dom.namespaces["xmlns:xmi"]
        ns_map = {"xmi" => xmlns_xmi}
        xpath = "//*[@xmi:id=#{xmi_id.inspect}]"
        logger.debug { "ns_map=#{ns_map.inspect}" }
        logger.debug { "xpath=#{xpath.inspect}" }
        elem = dom.at_xpath(xpath, ns_map)
        raise ParserError, "cannot resolve href=#{href.inspect} at #{xpath.inspect}" unless elem
        elem
      end
    end

    class ParserCore
      attr_accessor :top_level
      attr_reader :phase, :url, :dom, :root_obj

      def factory ; @top_level.factory ; end
      def logger ; @top_level.logger ; end

      def initialize top_level
        @top_level = top_level
        @root_obj = factory.new("xmi", "Root", {})
        setup()
      end

      def setup
        @phase = :inactive
        @hrefs = {}
        @elem_stack = []
        @obj_stack = []
        @xmi_id_to_object = {}
        @object_to_xmi_id = {}
        @root_object = nil
      end

      def call(url)
        setup
        @phase = :start
        @url = url.to_s
        @obj_stack.push(@root_obj)
        @dom = @top_level.load_xml(@url)
        @phase = :build
        parse_top_level(@dom)
        @phase = :resolve
        parse_top_level(@dom)
        @phase = :complete
        self
      end

      def parse_top_level(elem)
        elem.children[0].children.each do | e |
          if e.name == "documentation"
            if @phase == :build
              @top_level.documentation[@url] << e.content
            end
          else
            parse(e)
          end
        end
      end

      def parse_children(elem)
        elem.children.each{|e| parse(e) }
      end

      def parse(elem)
        # puts("#{@phase} : #{bare_xml_node(elem)}")
        _parse(elem)
      rescue ParserError
        raise
      rescue => reason
        data = {
          dom: [@url] + (@elem_stack + [elem]).map!{|e| bare_xml_node(e)},
          objs: ([@obj] + @obj_stack).map!{|o| "#<#{o.class} #{o.__id__}>"},
        }
        exc = ParserError.new(nil, reason, data)
        @top_level.errors << exc
        raise exc unless @top_level.continue_after_error
      end

      def _parse(elem)
        logger.debug { "### ######################################################" }
        logger.debug { "ELEM  : #{elem.name} @#{elem.object_id}" }
        logger.debug { "ATTRS : #{convert_attrs(elem).inspect}" }
        _add_element_stats(elem) if @phase == :build
        elem_desc = bare_xml_node(elem)
        attr = elem.name.to_sym
        parent = @obj_stack.last
        @elem_stack.push(elem)
        begin
          xmi_type, xmi_id, xmi_idref, href = parse_xmi_attrs(elem)
          # puts([xmi_type, xmi_id, xmi_idref, href].map(&:inspect))
          unique_id = xmi_id || xmi_idref
          unique_id &&= "#{@url}\##{unique_id}"
          case
          when xmi_idref
            if xmi_type || xmi_id
              raise ParserError, "has idref #{xmi_idref.inspect} and xmi_type #{xmi_type.inspect} xmi_id #{xmi_id.inspect}"
            end
            @obj = obj = @xmi_id_to_object[xmi_idref]
            case
            when @phase == :resolve
              unless obj
                raise ParserError, "unknown idref #{xmi_idref.inspect}"
              end
            end
          when xmi_type
            xmi_type_prefix, xmi_type_name = xmi_type.split(':', 2)
            properties = {}
            get_attr(elem, nil, nil) do | attr |
              properties[attr.name] = attr.value
            end
            @obj = obj = factory.new(xmi_type_prefix, xmi_type_name, properties, unique_id)
            @root_object ||= @obj
            # obj._.type = xmi_type
            # obj._.id = xmi_id
            # obj._.type_prefix = xmi_type_prefix
            # obj._.type_name = xmi_type_name
            # obj._.node_parent = parent
            # parent._.node_children << obj if parent
            if @obj.__id__ != @root_object.__id__
              associate(parent, :ownedElement, obj, elem_desc)
            end
            obj.owner = parent # !!! this might not be true for all models
            # factory.set_source_location(obj, @url, elem.line)
            if xmi_id
              @xmi_id_to_object[xmi_id] = obj
              @object_to_xmi_id[obj.__id__] = xmi_id
            end
            logger.debug { "PROPERTIES : #{properties.inspect}" }
            logger.debug { "OBJECT     : #{obj.inspect}" }
          when href
            if @phase == :build
              dom = @top_level.resolve_href(href)
              other = parse(dom)
              associate(parent, attr, other, elem_desc)
              logger.debug { "parent=#{parent}" }
              logger.debug { "attr=#{attr.inspect}" }
              logger.debug { "prop=#{parent.__send__(attr)}" }
            end
          when elem.attributes.empty?
            parent.__send__(:"#{elem.name}_add!", elem.content)
          else
            raise ParserError, "no xmi:type or xmi:idref"
          end

          if obj
            @obj_stack.push(obj)
            begin
              if @phase == :resolve && obj && parent
                logger.debug { "  obj=#{obj}" }
                logger.debug { "  parent=#{parent}" }
                associate(parent, attr, obj, elem_desc)
              end
              parse_children(elem)
            ensure
              @obj = @obj_stack.pop
            end
          end

          obj
        ensure
          @elem_stack.pop
        end
      end

      def _add_element_stats(elem)
        xmi_type, xmi_id, xmi_idref, href = parse_xmi_attrs(elem)
        top_level.stats[:xmi_type][xmi_type] += 1
        top_level.stats[:nil_xmi_type][elem.name] += 1 unless xmi_type
        # pp(xmi_idref: xmi_idref, name: elem.name) unless xmi_type
        top_level.stats[:href][href] += 1
        top_level.stats[:name][elem.name] += 1
        get_attr(elem, nil, nil) do | attr |
          top_level.stats[:properties][attr.name] += 1
        end
      end

      def associate dst, attr, obj, elem
        factory.associate(dst, attr, obj, elem) if dst
        dst
      end

      def parse_xmi_attrs(elem)
        xmi_type = get_attr(elem, 'xmi', 'type')&.value
        xmi_id = get_attr(elem, 'xmi', 'id')&.value
        xmi_idref = get_attr(elem, 'xmi', 'idref')&.value
        href = get_attr(elem, nil, 'href')&.value
        [xmi_type, xmi_id, xmi_idref, href]
      end

      def convert_attrs(elem)
        attrs = {}
        elem.attribute_nodes.each do | attr |
          name = attr.name
          if (prefix = attr.namespace&.prefix)
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

      def bare_xml_node(elem)
        elem = elem.dup
        elem.children.remove
        "#{@url}:#{elem.line} #{elem.to_xml}"
      end
    end
  end
end

