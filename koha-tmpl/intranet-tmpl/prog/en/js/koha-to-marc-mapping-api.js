//Fetch the Shelving locations using AJAX
//Build the replacement HTML for the shelving location options
//Then replace the existing HTML with this.
function reloadShelvingLocations(branch, framework, selectorElement) {

    if (typeof framework == "undefined" && typeof shelvingLocationMarcField == "undefined") {
        framework = "0"; //Get the default framework
    }

    $.ajax({
        url: "/cgi-bin/koha/svc/getShelvingLocations.pl",
        type: "POST",
        dataType: 'json',
        data: { 'branch' : branch, 'framework' : framework },
        success: function(data, textStatus, jqXHR) {

            var locations = data.locations;
            if ( selectorElement ) {
                var html_replacement = '<option value="" selected="selected"></option>\n';
                for (var k in locations) {
                    html_replacement += '<option value="'+ k +'">'+ locations[k] +'</option>\n';
                }
                $(selectorElement).html( html_replacement );
            }
            else {
                alert("ERROR in koha-to-marc-mapping-api.js: No element given to place new shelving locations into!");
            }
        },
        error: function(data, textStatus, jqXHR) {
            alert("ERROR in koha-to-marc-mapping-api.js: Couldn't make a decent AJAX-call!");
        }
    });
}