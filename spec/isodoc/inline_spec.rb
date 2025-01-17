require "spec_helper"

RSpec.describe IsoDoc do
  it "processes inline formatting" do
    output = IsoDoc::Iso::HtmlConvert.new({}).convert("test", <<~"INPUT", true)
      <iso-standard xmlns="http://riboseinc.com/isoxml">
        <preface>
          <foreword>
            <p>
              <em>A</em>
              <strong>B</strong>
              <sup>C</sup>
              <sub>D</sub>
              <tt>E</tt>
              <strike>F</strike>
              <smallcap>G</smallcap>
              <br/>
              <hr/>
              <bookmark id="H"/>
              <pagebreak/>
            </p>
          </foreword>
        </preface>
        <sections>
      </iso-standard>
    INPUT
    expect(xmlpp(output)).to be_equivalent_to xmlpp(<<~"OUTPUT")
      #{HTML_HDR}
            <br/>
            <div>
              <h1 class="ForewordTitle">Foreword</h1>
              <p>
                <i>A</i>
                <b>B</b>
                <sup>C</sup>
                <sub>D</sub>
                <tt>E</tt>
                <s>F</s>
                <span style="font-variant:small-caps;">G</span>
                <br/>
                <hr/>
                <a id="H"/>
                <br/>
              </p>
            </div>
            <p class="zzSTDTitle1"/>
          </div>
        </body>
      </html>
    OUTPUT
  end

  it "processes links" do
    output = IsoDoc::Iso::HtmlConvert.new({}).convert("test", <<~"INPUT", true)
      <iso-standard xmlns="http://riboseinc.com/isoxml">
        <preface>
          <foreword>
            <p>
              <link target="http://example.com"/>
              <link target="http://example.com">example</link>
              <link target="mailto:fred@example.com"/>
              <link target="mailto:fred@example.com">mailto:fred@example.com</link>
            </p>
          </foreword>
        </preface>
        <sections>
      </iso-standard>
    INPUT
    expect(xmlpp(output)).to be_equivalent_to xmlpp(<<~"OUTPUT")
      #{HTML_HDR}
            <br/>
            <div>
              <h1 class="ForewordTitle">Foreword</h1>
              <p>
                <a href="http://example.com">http://example.com</a>
                <a href="http://example.com">example</a>
                <a href="mailto:fred@example.com">fred@example.com</a>
                <a href="mailto:fred@example.com">mailto:fred@example.com</a>
              </p>
            </div>
            <p class="zzSTDTitle1"/>
          </div>
        </body>
      </html>
    OUTPUT
  end

  it "processes unrecognised markup" do
    output = IsoDoc::Iso::HtmlConvert.new({}).convert("test", <<~"INPUT", true)
      <iso-standard xmlns="http://riboseinc.com/isoxml">
        <preface>
          <foreword>
            <p>
              <barry fred="http://example.com">example</barry>
            </p>
          </foreword>
        </preface>
        <sections>
      </iso-standard>
    INPUT
    expect(xmlpp(output)).to be_equivalent_to xmlpp(<<~"OUTPUT")
      #{HTML_HDR}
            <br/>
            <div>
              <h1 class="ForewordTitle">Foreword</h1>
              <p>
                <para>
                  <b role="strong">&lt;barry fred=&quot;http://example.com&quot;&gt;example&lt;/barry&gt;</b>
                </para>
              </p>
            </div>
            <p class="zzSTDTitle1"/>
          </div>
        </body>
      </html>
    OUTPUT
  end

  it "processes AsciiMath and MathML" do
    output = IsoDoc::Iso::HtmlConvert.new({}).convert("test", <<~"INPUT", true)
      <iso-standard xmlns="http://riboseinc.com/isoxml">
        <preface>
          <foreword>
            <p>
              <stem type="AsciiMath">A</stem>
              <stem type="MathML"><m:math><m:row>X</m:row></m:math></stem>
              <stem type="None">Latex?</stem>
            </p>
          </foreword>
        </preface>
        <sections>
      </iso-standard>
    INPUT
    expect(xmlpp(output.sub(/<html/, "<html xmlns:m='m'"))).to be_equivalent_to xmlpp(<<~"OUTPUT")
      #{HTML_HDR.sub(/<html/, "<html xmlns:m='m'")}
            <br/>
            <div>
              <h1 class="ForewordTitle">Foreword</h1>
              <p>
                <span class="stem">(#(A)#)</span>
                <span class="stem">
                  <m:math>
                    <m:row>X</m:row>
                  </m:math>
                </span>
                <span class="stem">Latex?</span>
              </p>
            </div>
            <p class="zzSTDTitle1"/>
          </div>
        </body>
      </html>
    OUTPUT
  end

  it "overrides AsciiMath delimiters" do
    output = IsoDoc::Iso::HtmlConvert.new({}).convert("test", <<~"INPUT", true)
      <iso-standard xmlns="http://riboseinc.com/isoxml">
        <preface>
          <foreword>
            <p><stem type="AsciiMath">A</stem>(#((Hello))#)</p>
          </foreword>
        </preface>
        <sections>
      </iso-standard>
    INPUT
    expect(xmlpp(output)).to be_equivalent_to xmlpp(<<~"OUTPUT")
      #{HTML_HDR}
              <br/>
              <div>
                <h1 class="ForewordTitle">Foreword</h1>
              <p>
                <span class="stem">(#(((A)#)))</span>
                (#((Hello))#)
              </p>
            </div>
            <p class="zzSTDTitle1"/>
          </div>
        </body>
      </html>
    OUTPUT
  end

  it "processes eref types" do
    output = IsoDoc::Iso::HtmlConvert.new({}).convert("test", <<~"INPUT", true)
      <iso-standard xmlns="http://riboseinc.com/isoxml">
        <preface>
          <foreword>
            <p>
              <eref type="footnote" bibitemid="ISO712" citeas="ISO 712">A</stem>
              <eref type="inline" bibitemid="ISO712" citeas="ISO 712">A</stem>
            </p>
          </foreword>
        </preface>
        <bibliography>
          <references id="_normative_references" normative="true" obligation="informative">
            <title>1<tab/>
              Normative references</title>
            <bibitem id="ISO712" type="standard">
              <title format="text/plain">Cereals and cereal products</title>
              <docidentifier>ISO 712</docidentifier>
              <contributor>
                <role type="publisher"/>
                <organization>
                  <abbreviation>ISO</abbreviation>
                </organization>
              </contributor>
            </bibitem>
          </references>
        </bibliography>
      </iso-standard>
    INPUT
    expect(xmlpp(output)).to be_equivalent_to xmlpp(<<~"OUTPUT")
      #{HTML_HDR}
            <br/>
            <div>
              <h1 class="ForewordTitle">Foreword</h1>
              <p>
                <sup><a href="#ISO712">A</a></sup>
                <a href="#ISO712">A</a>
              </p>
            </div>
            <p class="zzSTDTitle1"/>
            <div>
              <h1>1&#160; Normative references</h1>
              <p id="ISO712" class="NormRef">ISO 712, <i>Cereals and cereal products</i></p>
            </div>
          </div>
        </body>
      </html>
    OUTPUT
  end

  it "processes eref content" do
    output = IsoDoc::Iso::PresentationXMLConvert.new({}).convert("test", <<~"INPUT", true)
      <iso-standard xmlns="http://riboseinc.com/isoxml">
        <preface>
          <foreword>
            <p>
              <eref bibitemid="IEV" citeas="IEV" type="inline">
                <locality type="clause">
                  <referenceFrom>1-2-3</referenceFrom>
                </locality>
              </eref>
              <eref bibitemid="ISO712" citeas="ISO 712" type="inline"/>
              <eref bibitemid="ISO712" type="inline"/>
              <eref bibitemid="ISO712" type="inline">
                <locality type="table">
                  <referenceFrom>1</referenceFrom>
                </locality>
              </eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="table">
                  <referenceFrom>1</referenceFrom>
                  <referenceTo>1</referenceTo>
                </locality>
              </eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="clause">
                  <referenceFrom>1</referenceFrom>
                </locality>
                <locality type="table">
                  <referenceFrom>1</referenceFrom>
                </locality>
              </eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="clause">
                  <referenceFrom>1</referenceFrom>
                </locality>
                <locality type="list">
                  <referenceFrom>a</referenceFrom>
                </locality>
              </eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="clause">
                  <referenceFrom>1</referenceFrom>
                </locality>
              </eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="clause">
                  <referenceFrom>1.5</referenceFrom>
                </locality>
              </eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="table">
                  <referenceFrom>1</referenceFrom>
                </locality>A</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="whole"/>
              </eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="locality:prelude">
                  <referenceFrom>7</referenceFrom>
                </locality>
              </eref>
              <eref bibitemid="ISO712" citeas="ISO 712" type="inline">A</eref>
            </p>
          </foreword>
        </preface>
        <bibliography>
          <references id="_normative_references" normative="true" obligation="informative">
            <title>Normative References</title>
            <bibitem id="ISO712" type="standard">
              <title format="text/plain">Cereals and cereal products</title>
              <docidentifier>ISO 712</docidentifier>
              <contributor>
                <role type="publisher"/>
                <organization>
                  <abbreviation>ISO</abbreviation>
                </organization>
              </contributor>
            </bibitem>
          </references>
        </bibliography>
      </iso-standard>
    INPUT
    expect(xmlpp(output).sub(%r{<i18nyaml>.*</i18nyaml>}m, "")).to be_equivalent_to xmlpp(<<~"OUTPUT")
      <?xml version='1.0'?>
      <iso-standard type="presentation" xmlns="http://riboseinc.com/isoxml">
        <preface>
          <foreword>
            <p>
              <eref bibitemid="IEV" citeas="IEV" type="inline">
                <locality type="clause">
                  <referenceFrom>1-2-3</referenceFrom>
                </locality>IEV, 1-2-3</eref>
              <eref bibitemid="ISO712" citeas="ISO 712" type="inline">ISO 712</eref>
              <eref bibitemid="ISO712" type="inline">ISO 712</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="table">
                  <referenceFrom>1</referenceFrom>
                </locality>ISO 712, Table 1</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="table">
                  <referenceFrom>1</referenceFrom>
                  <referenceTo>1</referenceTo>
                </locality>ISO 712, Table 1–1</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="clause">
                  <referenceFrom>1</referenceFrom>
                </locality>
                <locality type="table">
                  <referenceFrom>1</referenceFrom>
                </locality>ISO 712, Clause 1, Table 1</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="clause">
                  <referenceFrom>1</referenceFrom>
                </locality>
                <locality type="list">
                  <referenceFrom>a</referenceFrom>
                </locality>ISO 712, Clause 1 a)</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="clause">
                  <referenceFrom>1</referenceFrom>
                </locality>ISO 712, Clause 1</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="clause">
                  <referenceFrom>1.5</referenceFrom>
                </locality>ISO 712, 1.5</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="table">
                  <referenceFrom>1</referenceFrom>
                </locality>A</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="whole"/>ISO 712, Whole of text</eref>
              <eref bibitemid="ISO712" type="inline">
                <locality type="locality:prelude">
                  <referenceFrom>7</referenceFrom>
                </locality>ISO 712, Prelude 7</eref>
              <eref bibitemid="ISO712" citeas="ISO 712" type="inline">A</eref>
            </p>
          </foreword>
        </preface>
        <bibliography>
          <references id="_normative_references" normative="true" obligation="informative">
            <title depth="1">1<tab/>
              Normative References</title>
            <bibitem id="ISO712" type="standard">
              <title format="text/plain">Cereals and cereal products</title>
              <docidentifier>ISO 712</docidentifier>
              <contributor>
                <role type="publisher"/>
                <organization>
                  <abbreviation>ISO</abbreviation>
                </organization>
              </contributor>
            </bibitem>
          </references>
        </bibliography>
      </iso-standard>
    OUTPUT
  end
end
