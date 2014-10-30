//IN THIS FILE
// These functions mimick the ones found in C4::OPLIB::Labels, for consistency.

var shelvingLabelsMap;

function getShelvingLabelsMap() {
    $.get("/cgi-bin/koha/svc/OPLIB/getShelvingLabelsMap", function (sjson) {
        shelvingLabelsMap = sjson;
    });
}

function getLabelFromMap( branchcode, location, itype, ccode ) {
    if (! shelvingLabelsMap) {
        getShelvingLabelsMap();
    }
    
    if (! branchcode) {
        branchcode = '';
    }
    if (! location) {
        location = '';
    }
    if (! itype) {
        itype = '';
    }
    if (! ccode) {
        ccode = '';
    }
    
    branchlevel = shelvingLabelsMap[ branchcode ];
    if (! branchlevel) { branchlevel = shelvingLabelsMap[ '' ]; }
    
    locationlevel = branchlevel[ location ];
    if (! locationlevel) { locationlevel = branchlevel[ '' ]; }
    
    itypelevel = locationlevel[ itype ];
    if (! itypelevel) { itypelevel = locationlevel[ '' ]; }
    
    ccodelevel = itypelevel[ ccode ];
    if (! ccodelevel) { ccodelevel = itypelevel[ '' ]; }
    
    return ccodelevel;
}
