The old t/ test hierarchy is a complete mess.
Look into establishing a good test hierarchy to more consistently know where to
put tests for specific modules/features.

Look into tagging tests by the filename, for ex:
    t2/C4/Matcher.i.t
    t2/C4/Matcher.u.t
    t2/C4/Matcher.b.t

    i = integration
    u = unit
    b = behaviour

    C4/Matcher tests functionality across different API's
        like REST, cli cronjobs, CGI opac, CGI staff, ILS-DI, OAI-PMH ?

Or maybe better to group test by interface?
    Core/C4/Matcher.i.t   #Core module tests using internal API
    REST/Matcher.b.t      #REST API tests
    Page/cataloguing/deduplicator.pl #PageObject tests

    ??
