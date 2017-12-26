require "date"
require "nokogiri"
require "htmlentities"
require "json"
require "pathname"
require "open-uri"
require "pp"

module Asciidoctor
  module ISO
    module Utils
      class << self
        def current_location(node)
          if node.respond_to?(:lineno) && !node.lineno.nil? &&
              !node.lineno.empty?
            return "Line #{node.lineno}"
          end
          if node.respond_to?(:id) && !node.id.nil?
            return "ID #{node.id}"
          end
          while !node.nil? && (!node.respond_to?(:level) ||
              node.level.positive?) && node.context != :section
            node = node.parent
            if !node.nil? && node.context == :section
              return "Section: #{node.title}"
            end
          end
          "??"
        end

        def style_warning(node, msg, text)
          warntext = "ISO style: WARNING (#{current_location(node)}): #{msg}"
          warntext += ": #{text}" if text
          warn warntext
        end

      end

      def convert(node, transform = nil, opts = {})
        transform ||= node.node_name
        opts.empty? ? (send transform, node) : (send transform, node, opts)
      end

      def document_ns_attributes(_doc)
        nil
      end

      def cleanup(xmldoc)
        intro_cleanup(xmldoc)
        termdef_cleanup(xmldoc)
        isotitle_cleanup(xmldoc)
        tablenote_cleanup(xmldoc)
        formula_cleanup(xmldoc)
        figure_cleanup(xmldoc)
        back_cleanup(xmldoc)
        ref_cleanup(xmldoc)
        xmldoc
      end

      def intro_cleanup(xmldoc)
        intro = xmldoc.at("//introduction")
        foreword = xmldoc.at("//foreword")
        front = xmldoc.at("//front")
        unless foreword.nil? || front.nil?
          foreword.remove
          front << foreword
        end
        unless intro.nil? || front.nil?
          intro.remove
          front << intro
        end
      end

      def termdef_cleanup(xmldoc)
        # release termdef tags from surrounding paras
        nodes = xmldoc.xpath("//p/admitted_term | //p/termsymbol |
                             //p/deprecated_term")
        while !nodes.empty?
          nodes[0].parent.replace(nodes[0].parent.children)
          nodes = xmldoc.xpath("//p/admitted_term | //p/termsymbol |
                               //p/deprecated_term")
        end
        xmldoc.xpath("//termdef/p/stem").each do |a|
          if a.parent.elements.size == 1
            # para containing just a stem expression
            t = Nokogiri::XML::Element.new("termsymbol", xmldoc)
            parent = a.parent
            a.remove
            t.children = a
            parent.replace(t)
          end
        end
        xmldoc.xpath("//p/termdomain").each do |a|
          prev = a.parent.previous
          a.remove
          prev.next = a
        end
      end

      def isotitle_cleanup(xmldoc)
        # Remove italicised ISO titles
        xmldoc.xpath("//isotitle").each do |a|
          if a.elements.size == 1 && a.elements[0].name == "em"
            a.children = a.elements[0].children
          end
        end
      end

      def tablenote_cleanup(xmldoc)
        # move notes after table footer
        xmldoc.xpath("//tfoot/tr/td/note | //tfoot/tr/th/note").each do |n|
          target = n.parent.parent.parent.parent
          n.remove
          target << n
        end
      end

      def formula_cleanup(xmldoc)
        # include where definition list inside stem block
        xmldoc.xpath("//formula").each do |s|
          if !s.next_element.nil? && s.next_element.name == "p" &&
              s.next_element.content == "where" &&
              !s.next_element.next_element.nil? &&
              s.next_element.next_element.name == "dl"
            dl = s.next_element.next_element.remove
            s.next_element.remove
            s << dl
          end
        end
      end

      def figure_cleanup(xmldoc)
        # include key definition list inside figure
        xmldoc.xpath("//figure").each do |s|
          if !s.next_element.nil? && s.next_element.name == "p" &&
              s.next_element.content =~ /^\s*Key\s*$/m &&
              !s.next_element.next_element.nil? &&
              s.next_element.next_element.name == "dl"
            dl = s.next_element.next_element.remove
            s.next_element.remove
            s << dl
          end
        end

        # examples containing only figures become subfigures of figures
        nodes = xmldoc.xpath("//example/figure")
        while !nodes.empty?
          nodes[0].parent.name = "figure"
          nodes = xmldoc.xpath("//example/figure")
        end
      end

      def back_cleanup(xmldoc)
        # move annex/bibliography to back
        if !xmldoc.xpath("//annex | //bibliography").empty?
          b = Nokogiri::XML::Element.new("back", xmldoc)
          xmldoc.root << b
          xmldoc.xpath("//annex").each do |e|
            e.remove
            b << e
          end
          xmldoc.xpath("//bibliography").each do |e|
            e.remove
            b << e
          end
        end
      end

      def ref_cleanup(xmldoc)
        # move ref before p
        xmldoc.xpath("//p/ref").each do |r|
          parent = r.parent
          r.remove
          parent.previous = r
        end

        xmldoc
      end

      # block for processing XML document fragments as XHTML,
      # to allow for HTMLentities
      def noko(&block)
        # fragment = ::Nokogiri::XML::DocumentFragment.parse("")
        # fragment.doc.create_internal_subset("xml", nil, "xhtml.dtd")
        head = <<HERE
        <!DOCTYPE html SYSTEM
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head> <title></title> <meta charset="UTF-8" /> </head>
        <body> </body> </html>
HERE
        doc = ::Nokogiri::XML.parse(head)
        fragment = doc.fragment("")
        ::Nokogiri::XML::Builder.with fragment, &block
        fragment.to_xml(encoding: "US-ASCII").lines.map do |l|
          l.gsub(/\s*\n/, "")
        end
      end

      def attr_code(attributes)
        attributes = attributes.reject { |_, val| val.nil? }.map
        attributes.map do |k, v|
          [k, (v.is_a? String) ? HTMLEntities.new.decode(v) : v]
        end.to_h
      end

      def current_location(node)
        if node.respond_to?(:lineno) && !node.lineno.nil? &&
            !node.lineno.empty?
          return "Line #{node.lineno}"
        end
        if node.respond_to?(:id) && !node.id.nil?
          return "ID #{node.id}"
        end
        while !node.nil? && (!node.respond_to?(:level) ||
            node.level.positive?) && node.context != :section
          node = node.parent
          if !node.nil? && node.context == :section
            return "Section: #{node.title}"
          end
        end
        "??"
      end

      def warning(node, msg, text)
        warntext = "asciidoctor: WARNING (#{current_location(node)}): #{msg}"
        warntext += ": #{text}" if text
        warn warntext
      end

      # if node contains blocks, flatten them into a single line;
      # and extract only raw text
      def flatten_rawtext(node)
        result = []
        if node.respond_to?(:blocks) && node.blocks?
          node.blocks.each { |b| result << flatten_rawtext(b) }
        elsif node.respond_to?(:lines)
          node.lines.each do |x|
            if node.respond_to?(:context) && (node.context == :literal ||
                node.context == :listing)
              result << x.gsub(/</, "&lt;").gsub(/>/, "&gt;")
            else
              # strip not only HTML tags <tag>,
              # but also Asciidoc crossreferences <<xref>>
              result << x.gsub(/<[^>]*>+/, "")
            end
          end
        elsif node.respond_to?(:text)
          result << node.text.gsub(/<[^>]*>+/, "")
        else
          result << node.content.gsub(/<[^>]*>+/, "")
        end
        result.reject(&:empty?)
      end
    end
  end
end
