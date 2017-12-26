require "htmlentities"
require "uri"

module Asciidoctor
  module ISO
    module Blocks
      def stem(node)
        stem_attributes = {
          anchor: node.id,
        }
        # NOTE: html escaping is performed by Nokogiri
        stem_content = node.lines.join("\n")

        noko do |xml|
          xml.formula **attr_code(stem_attributes) do |s|
            s.stem stem_content
            Validate::style(node, stem_content)
          end
        end
      end

      def sidebar(node)
        if $draft
          note_attributes = {
            source: node.attr("source") 
          }
          content = Utils::flatten_rawtext(node.content).join("\n")
          noko do |xml|
            xml.review_note content, **attr_code(note_attributes)
          end
        end
      end

      def termnote(node)
        note_attributes = { anchor: node.id }
        warning(node, "comment can not contain blocks of text in XML RFC", node.content) if node.blocks?
        noko do |xml|
          xml.termnote **attr_code(note_attributes) do |xml_cref|
            xml_cref << node.content
            Validate::style(node, Utils::flatten_rawtext(node.content).join("\n"))
          end
        end.join("\n")
      end

      def admonition(node)
        return termnote(node) if $term_def
        noko do |xml|
          xml.note **attr_code(anchor: node.id) do |xml_cref|
            if node.blocks?
              xml_cref << node.content
            else
              xml_cref.p { |p| p << node.content }
            end
            Validate::style(node, Utils::flatten_rawtext(node.content).join("\n"))
          end
        end.join("\n")
      end

      def term_example(node)
        noko do |xml|
          xml.termexample **attr_code(anchor: node.id) do |ex|
            ex << node.content
            Validate::style(node, Utils::flatten_rawtext(node.content).join("\n"))
          end
        end.join("\n")
      end

      def example(node)
        return term_example(node) if $term_def
        noko do |xml|
          xml.example **attr_code(anchor: node.id) do |ex|
            ex << node.content
            Validate::style(node, Utils::flatten_rawtext(node.content).join("\n"))
          end
        end.join("\n")
      end

      def preamble(node)
        result = []
        result << noko do |xml|
          xml.foreword do |xml_abstract|
            content = node.content
            xml_abstract << content
            Validate::foreword_style(node, Utils::flatten_rawtext(content).join("\n"))
          end
        end
        result
      end

      def section(node)
        attrs = { anchor: node.id.empty? ? nil : node.id }
        noko do |xml|
          case node.title.downcase
          when "introduction"
            xml.introduction **attr_code(attrs) do |xml_section|
              xml_section << node.content
            end
          when "patent notice"
            xml.patent_notice do |xml_section|
              xml_section << node.content
            end
          when "scope"
            xml.scope **attr_code(attrs) do |xml_section|
              xml_section << node.content
            end
          when "normative references"
            $norm_ref = true
            xml.norm_ref **attr_code(attrs) do |xml_section|
              xml_section << node.content
            end
            $norm_ref = false
          when "terms and definitions"
            $term_def = true
            xml.terms_defs **attr_code(attrs) do |xml_section|
              xml_section << node.content
            end
            $term_def = false
          when "symbols and abbreviations"
            xml.symbols_abbrevs **attr_code(attrs) do |xml_section|
              xml_section << node.content
            end
          when "bibliography"
            $biblio = true
            xml.bibliography **attr_code(attrs) do |xml_section|
              xml_section << node.content
            end
            $biblio = true
          else
            if $term_def
              xml.termdef **attr_code(attrs) do |xml_section|
                xml_section.term { |name| name << node.title }
                xml_section << node.content
              end
            elsif node.attr("style") == "appendix"
              attrs[:subtype] = node.attributes.has_key?("subtype") ? node.attr("subtype") : "informative"
              xml.annex **attr_code(attrs) do |xml_section|
                xml_section.name { |name| name << node.title }
                xml_section << node.content
              end
            else
              xml.clause **attr_code(attrs) do |xml_section|
                unless node.title.nil?
                  xml_section.name { |name| name << node.title }
                end
                xml_section << node.content
              end
            end
          end
        end.join("\n")
      end

      def image(node)
        uri = node.image_uri node.attr("target")
        artwork_attributes = {
          anchor: node.id,
          src: uri,
        }

        noko do |xml|
          xml.figure **attr_code(artwork_attributes) do |f|
            f.name { |name| name << node.title } unless node.title.nil?
          end
        end
      end

      def quote(node)
        noko do |xml|
          xml.quote **attr_code(anchor: node.id) do |xml_blockquote|
            if node.blocks?
              xml_blockquote << node.content
            else
              xml_blockquote.p { |p| p << node.content }
            end
          end
        end
      end

      def listing(node)
        # NOTE: html escaping is performed by Nokogiri
        noko do |xml|
          if node.parent.context != :example
            xml.figure do |xml_figure|
              xml_figure.sourcecode { |s| s << node.content }
            end
          else
            xml.sourcecode { |s| s << node.content }
          end
        end
      end
    end
  end
end
