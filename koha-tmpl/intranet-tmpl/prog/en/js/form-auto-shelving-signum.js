/* Usability improvements (KD-130):
 * Fills the signum-field (subfield "o") automatically when the shelving location changes.
 */
function addAutoShelvingLoc(fieldVariant) {
    $(document).ready(function() {
        var fieldCCode, fieldHomebranch, fieldPermLocation, fieldSignum, fieldItype, fieldOrder;
        if (fieldVariant == "cataloguing") {
            fieldCCode        = $("select[id^='tag_952_subfield_8_']");
            fieldHomebranch   = $("select[id^='tag_952_subfield_a_']");
            fieldPermLocation = $("select[id^='tag_952_subfield_c_']");
            fieldSignum       = $("[id^='tag_952_subfield_o_']");
            fieldItype        = $("select[id^='tag_952_subfield_y_']");
        } else {
            fieldCCode        = $("#subfield8 select[name^='field_value']");
            fieldHomebranch   = $("#subfielda select[name^='field_value']");
            fieldPermLocation = $("#subfieldc select[name^='field_value']");
            fieldSignum       = $("#subfieldo input[name^='field_value']");
            fieldItype        = $("#subfieldy select[name^='field_value']");
        }

        fieldCCode.change (function() {
            getShelvingLocForm(fieldCCode, fieldHomebranch, fieldPermLocation, fieldSignum, fieldItype);
        });
        fieldHomebranch.change (function() {
            getShelvingLocForm(fieldCCode, fieldHomebranch, fieldPermLocation, fieldSignum, fieldItype);
        });
        fieldPermLocation.change (function() {
            getShelvingLocForm(fieldCCode, fieldHomebranch, fieldPermLocation, fieldSignum, fieldItype);
        });
        fieldItype.change (function() {
            getShelvingLocForm(fieldCCode, fieldHomebranch, fieldPermLocation, fieldSignum, fieldItype);
        });
        fieldSignum.change (function() {
            getShelvingLocForm(fieldCCode, fieldHomebranch, fieldPermLocation, fieldSignum, fieldItype);
        });

        $.get("/cgi-bin/koha/svc/OPLIB/getShelvingLabelsMap", function (sjson) {
            shelvingLabelsMap = sjson;
            getShelvingLocForm(fieldCCode, fieldHomebranch, fieldPermLocation, fieldSignum, fieldItype);
        });

    });
} // addAutoShelvingLoc

//Recalculate the Signum-field from ccode, itype, homebranch and permanent location.
function getShelvingLocForm( fieldCCode, fieldHomebranch, fieldPermLocation, fieldSignum, fieldItype ) {
        var homebranch  = fieldHomebranch.val();
        var shelvingLoc = fieldPermLocation.val();
        var itype       = fieldItype.val();
        var ccode       = fieldCCode.val();

        //Initialize the itemcallnumber/spine label components
        var fullLoc     = "";
        var callNumber  = "";
        var mainHeading = "";

        //Get the shelving location code, make sure uninitialized values are "" so they can be used with oplib_label_mappings.
        if (!(homebranch && homebranch.length !== 0)) {
            homebranch = "";
        }
        if (!(shelvingLoc && shelvingLoc.length !== 0)) {
            shelvingLoc = "";
        }
        if (!(itype && itype.length !== 0)) {
            itype = "";
        }
        if (!(ccode && ccode.length !== 0)) {
            ccode = "";
        }
        var fullLoc = getLabelFromMap(  homebranch, shelvingLoc, itype, ccode  );
        //Mappings done!

        //Get the callNumber from MARC
        var marc84a = $("input[name^='marcfield084a']").val();
        if (marc84a) {
            callNumber = marc84a;
        }

        //Get the main heading from the MARC author or title
        var marc100a = $("input[name^='marcfield100a']").val();
        var marc110a = $("input[name^='marcfield110a']").val();
        var marc245a = $("input[name^='marcfield245a']").val();
        if (marc100a || marc110a) {
            if (marc100a) {
                marc100a = marc100a.substring(0, 3).toUpperCase();
                mainHeading = marc100a;
            } else if (marc110a) {
                marc110a = marc110a.substring(0, 3).toUpperCase();
                mainHeading = marc110a;
            }
        }
        else if (marc245a) {
            marc245a = marc245a.substring(0, 3).toUpperCase();
            mainHeading = marc245a;
        }
        //Main heading done!

        //LUMME #112
        $.get("/cgi-bin/koha/svc/OPLIB/getItemcallnumberOrder", function (pref) {
            //Check should we overwrite an existing Signum. We should overwrite only when we have a perfect Signum to replace the old with.
            //But don't replace the signum and call number once they have been given.
            var signumComponents = 3;
            var oldSignum = fieldSignum.val();
            var oldSignumFields = oldSignum.split(" ");
            var oldCallNumber = (pref.order == 'number') ? oldSignumFields[0]: oldSignumFields[1];
            var oldFullLoc = (pref.order == 'number') ? oldSignumFields[2]: oldSignumFields[0];
            var oldMainHeading = (pref.order == 'number') ? oldSignumFields[1]: oldSignumFields[2];
            if (oldCallNumber && oldCallNumber.match(/^\d?\d/)) {
                callNumber = oldCallNumber;
            }
            //We only change the fullLoc, others need to be manually changed once defined.
            if (oldMainHeading) {
                mainHeading = oldMainHeading;
            }
            if (  (!fullLoc || !callNumber || !mainHeading) && oldSignumFields.length >= signumComponents  ) {
                return 0; // Do not mess with existing user-defined shelving locations
            }
            // Checks the system preferences for the order
            if (pref.order == 'number') {
                fieldSignum.val(  callNumber + " " + mainHeading + " " + fullLoc  );
            } else {
                fieldSignum.val(  fullLoc + " " + callNumber + " " + mainHeading  );
            }

        });
        
} // getShelvingLocForm
