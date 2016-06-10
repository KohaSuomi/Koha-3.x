package t2::C4::Matcher_context;

use Modern::Perl '2014';

use t::lib::TestObjects::BiblioFactory;
use t::lib::TestObjects::MatcherFactory;
use t::lib::TestObjects::ObjectFactory;

sub createTwoDuplicateRecords {
    my (@testContexts) = @_;
    return t::lib::TestObjects::BiblioFactory->createTestGroup([
<<RECORD,
<record
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
    xmlns="http://www.loc.gov/MARC21/slim">

  <leader>01147njm a22003014i 4500</leader>
  <controlfield tag="001">4330471</controlfield>
  <controlfield tag="003">FI-BTJ</controlfield>
  <controlfield tag="005">20160527130624.0</controlfield>
  <controlfield tag="007">sd||||g|||m||d</controlfield>
  <controlfield tag="008">160308s2016    fi ||||  ||||||   | fin|c</controlfield>
  <datafield tag="020" ind1="3" ind2=" ">
    <subfield code="a">889853057023first</subfield>
  </datafield>
  <datafield tag="024" ind1="1" ind2=" ">
    <subfield code="a">889853057023first</subfield>
  </datafield>
  <datafield tag="028" ind1="0" ind2="1">
    <subfield code="b">Sound of Finland</subfield>
    <subfield code="a">88985305702first</subfield>
  </datafield>
  <datafield tag="041" ind1="0" ind2=" ">
    <subfield code="d">fin</subfield>
  </datafield>
  <datafield tag="084" ind1=" " ind2=" ">
    <subfield code="a">78.8911</subfield>
    <subfield code="2">ykl</subfield>
  </datafield>
  <datafield tag="084" ind1=" " ind2=" ">
    <subfield code="a">78.891</subfield>
    <subfield code="2">ykl</subfield>
  </datafield>
  <datafield tag="100" ind1="1" ind2=" ">
    <subfield code="a">Takalo, Jukka,</subfield>
    <subfield code="e">esittäjä.</subfield>
  </datafield>
  <datafield tag="245" ind1="1" ind2="0">
    <subfield code="a">Suomen kuningas /</subfield>
    <subfield code="c">Jukka Takalo.</subfield>
  </datafield>
  <datafield tag="260" ind1=" " ind2=" ">
    <subfield code="a">[S.l.] :</subfield>
    <subfield code="b">Sony Music Entertainment Finland,</subfield>
    <subfield code="c">p 2016.</subfield>
  </datafield>
</record>
RECORD
<<RECORD,
<record
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
    xmlns="http://www.loc.gov/MARC21/slim">

  <leader>01147njm a22003014i 4500</leader>
  <controlfield tag="001">4330471</controlfield>
  <controlfield tag="003">FI-BTJ</controlfield>
  <controlfield tag="005">20160503195934.0</controlfield>
  <controlfield tag="007">sd||||g|||m||d</controlfield>
  <controlfield tag="008">160308s2016    fi ||||  ||||||   | fin|c</controlfield>
  <datafield tag="020" ind1="3" ind2=" ">
    <subfield code="a">889853057023second</subfield>
  </datafield>
  <datafield tag="024" ind1="1" ind2=" ">
    <subfield code="a">889853057023second</subfield>
  </datafield>
  <datafield tag="028" ind1="0" ind2="1">
    <subfield code="b">Sound of Finland</subfield>
    <subfield code="a">88985305702second</subfield>
  </datafield>
  <datafield tag="041" ind1="0" ind2=" ">
    <subfield code="d">fin</subfield>
  </datafield>
  <datafield tag="084" ind1=" " ind2=" ">
    <subfield code="a">78.8911</subfield>
    <subfield code="2">ykl</subfield>
  </datafield>
  <datafield tag="084" ind1=" " ind2=" ">
    <subfield code="a">78.891</subfield>
    <subfield code="2">ykl</subfield>
  </datafield>
  <datafield tag="100" ind1="1" ind2=" ">
    <subfield code="a">Takalo, Jukka,</subfield>
    <subfield code="e">esittäjä.</subfield>
  </datafield>
  <datafield tag="245" ind1="1" ind2="0">
    <subfield code="a">Suomen kuningas /</subfield>
    <subfield code="c">Jukka Takalo.</subfield>
  </datafield>
  <datafield tag="260" ind1=" " ind2=" ">
    <subfield code="a">[S.l.] :</subfield>
    <subfield code="b">Sony Music Entertainment Finland,</subfield>
    <subfield code="c">p 2016.</subfield>
  </datafield>
</record>
RECORD
    ], 'biblioitems.isbn', @testContexts);
}

sub createControlNumberMatcher {
    my (@testContexts) = @_;
    return t::lib::TestObjects::MatcherFactory->createTestGroup(
            {code => 'CNI',
             description => 'Control number identifier',
             threshold => 1000,
             matchpoints => [
                {
                   index       => 'control-number',
                   score       => 1000,
                   components => [{
                        tag         => '001',
                        subfields   => '',
                        offset      => 0,
                        length      => 0,
                        norms       => [''],
                   }]
                },
             ],
            required_checks => [
                {
                    source => [{
                        tag         => '003',
                        subfields   => '',
                        offset      => 0,
                        length      => 0,
                        norms       => [''],
                    }],
                    target => [{
                        tag         => '003',
                        subfields   => '',
                        offset      => 0,
                        length      => 0,
                        norms       => [''],
                    }],
                },
            ],
            },
        undef, @testContexts
    );
}

1;
