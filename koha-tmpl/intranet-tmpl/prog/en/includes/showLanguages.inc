[% FOREACH subfield IN languagecodes.keys.sort %]
    [% FOREACH languages IN languagecodes.$subfield %]
        [% FOREACH lang_code IN languages %]
            <!-- <img src="/intranet-tmpl/prog/img/phoca_flag_icons/[% lang_code %].png" alt="[% lang_code %]" title="[% lang_code %]" class="lang_icon" /> -->
            <img src="/intranet-tmpl/prog/img/famfamfam/languages/[% lang_code %].png" alt="[% lang_code %]" title="[% lang_code %]" class="lang_icon" />
        [% END %]
    [% END %]
[% END %]