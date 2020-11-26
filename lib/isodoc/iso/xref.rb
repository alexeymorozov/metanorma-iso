module IsoDoc
  module Iso
    class Xref < IsoDoc::Xref
      def initial_anchor_names(d)
        if @klass.amd(d)
          d.xpath(ns("//preface/*")).each { |c| c.element? and preface_names(c) }
          sequential_asset_names(d.xpath(ns("//preface/*")))
          middle_section_asset_names(d)
          termnote_anchor_names(d)
          termexample_anchor_names(d)
        else
          super
        end
        introduction_names(d.at(ns("//introduction")))
      end

      # we can reference 0-number clauses in introduction
      def introduction_names(clause)
        return if clause.nil?
        clause.at(ns("./clause")) and @anchors[clause["id"]] = 
          { label: "0", level: 1, xref: clause.at(ns("./title"))&.text, type: "clause" }
        clause.xpath(ns("./clause")).each_with_index do |c, i|
          section_names1(c, "0.#{i + 1}", 2)
        end
      end

      def annex_names(clause, num)
        appendix_names(clause, num)
        super
      end

      def appendix_names(clause, num)
        clause.xpath(ns("./appendix")).each_with_index do |c, i|
          @anchors[c["id"]] = anchor_struct(i + 1, nil, @labels["appendix"], "clause")
          @anchors[c["id"]][:level] = 2
          @anchors[c["id"]][:container] = clause["id"]
          c.xpath(ns("./clause | ./references")).each_with_index do |c, j|
            appendix_names1(c, l10n("#{@labels["appendix"]} #{i + 1}.#{j + 1}"), 3, clause["id"])
          end
        end
      end

      def section_names1(clause, num, level)
        @anchors[clause["id"]] =
          { label: num, level: level, xref: num }
        # subclauses are not prefixed with "Clause"
        clause.xpath(ns("./clause | ./terms | ./term | ./definitions | "\
                        "./references")).
                       each_with_index do |c, i|
          section_names1(c, "#{num}.#{i + 1}", level + 1)
        end
      end

      def annex_names1(clause, num, level)
        @anchors[clause["id"]] = { label: num, xref: num, level: level }
        clause.xpath(ns("./clause | ./references")).each_with_index do |c, i|
          annex_names1(c, "#{num}.#{i + 1}", level + 1)
        end
      end

      def appendix_names1(clause, num, level, container)
        @anchors[clause["id"]] = { label: num, xref: num, level: level, container: container }
        clause.xpath(ns("./clause | ./references")).each_with_index do |c, i|
          appendix_names1(c, "#{num}.#{i + 1}", level + 1, container)
        end
      end

      def hierarchical_formula_names(clause, num)
        c = IsoDoc::XrefGen::Counter.new
        clause.xpath(ns(".//formula")).each do |t|
          next if t["id"].nil? || t["id"].empty?
          @anchors[t["id"]] =
            anchor_struct("#{num}#{hiersep}#{c.increment(t).print}", t,
                          t["inequality"] ? @labels["inequality"] : @labels["formula"],
                          "formula", t["unnumbered"])
        end
      end

      def figure_anchor(t, sublabel, label)
        @anchors[t["id"]] = anchor_struct(
          (sublabel ? "#{label} #{sublabel}" : label),
          nil, @labels["figure"], "figure", t["unnumbered"])
        sublabel && t["unnumbered"] != "true" and
          @anchors[t["id"]][:label] = sublabel
      end

      def sequential_figure_names(clause)
        c = IsoDoc::XrefGen::Counter.new
        j = 0
        clause.xpath(ns(".//figure | .//sourcecode[not(ancestor::example)]")).
          each do |t|
          j = subfigure_increment(j, c, t)
          sublabel = j.zero? ? nil : "#{(j+96).chr})"
          next if t["id"].nil? || t["id"].empty?
          figure_anchor(t, sublabel, c.print)
        end
      end

      def hierarchical_figure_names(clause, num)
        c = IsoDoc::XrefGen::Counter.new
        j = 0
        clause.xpath(ns(".//figure |  .//sourcecode[not(ancestor::example)]")).
          each do |t|
          j = subfigure_increment(j, c, t)
          label = "#{num}#{hiersep}#{c.print}"
          sublabel = j.zero? ? nil : "#{(j+96).chr})"
          next if t["id"].nil? || t["id"].empty?
          figure_anchor(t, sublabel, label)
        end
      end

      def reference_names(ref)
        super
        @anchors[ref["id"]] = { xref: @anchors[ref["id"]][:xref].
                                sub(/ \(All Parts\)/i, "") }
      end
    end
  end
end
