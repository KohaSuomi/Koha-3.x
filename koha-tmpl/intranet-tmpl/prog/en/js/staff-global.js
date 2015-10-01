// staff-global.js
if ( KOHA === undefined ) var KOHA = {};

function _(s) { return s; } // dummy function for gettext

// http://stackoverflow.com/questions/1038746/equivalent-of-string-format-in-jquery/5341855#5341855
String.prototype.format = function() { return formatstr(this, arguments) }
function formatstr(str, col) {
    col = typeof col === 'object' ? col : Array.prototype.slice.call(arguments, 1);
    var idx = 0;
    return str.replace(/%%|%s|%(\d+)\$s/g, function (m, n) {
        if (m == "%%") { return "%"; }
        if (m == "%s") { return col[idx++]; }
        return col[n];
    });
};


// http://stackoverflow.com/questions/14859281/select-tab-by-name-in-jquery-ui-1-10-0/16550804#16550804
$.fn.tabIndex = function () {
    return $(this).parent().children('div').index(this);
};
$.fn.selectTabByID = function (tabID) {
    $(this).tabs("option", "active", $(tabID).tabIndex());
};

 $(document).ready(function() {
    $('#header_search').tabs().on( "tabsactivate", function(e, ui) { $(this).find("div:visible").find('input').eq(0).focus(); });

    $(".close").click(function(){ window.close(); });

    if($("#header_search #checkin_search").length > 0){ shortcut.add('Alt+r',function (){ $("#header_search").selectTabByID("#checkin_search"); $("#ret_barcode").focus(); }); } else { shortcut.add('Alt+r',function (){ location.href="/cgi-bin/koha/circ/returns.pl"; }); }
    if($("#header_search #circ_search").length > 0){ shortcut.add('Alt+u',function (){ $("#header_search").selectTabByID("#circ_search"); $("#findborrower").focus(); }); } else { shortcut.add('Alt+u',function(){ location.href="/cgi-bin/koha/circ/circulation.pl"; }); }
    if($("#header_search #catalog_search").length > 0){ shortcut.add('Alt+q',function (){ $("#header_search").selectTabByID("#catalog_search"); $("#search-form").focus(); }); } else { shortcut.add('Alt+q',function(){ location.href="/cgi-bin/koha/catalogue/search.pl"; }); }

    $(".focus").focus();
    $(".validated").each(function() {
        $(this).validate();
    });

    $("#logout").on("click",function(){
        logOut();
    });
    $("#helper").on("click",function(){
        openHelp();
        return false;
    });

    $("body").on("keypress", ".noEnterSubmit", function(e){
        return checkEnter(e);
    });
});

// http://jennifermadden.com/javascript/stringEnterKeyDetector.html
function checkEnter(e){ //e is event object passed from function invocation
    var characterCode; // literal character code will be stored in this variable
    if(e && e.which){ //if which property of event object is supported (NN4)
        e = e;
        characterCode = e.which; //character code is contained in NN4's which property
    } else {
        e = window.event;
        characterCode = e.keyCode; //character code is contained in IE's keyCode property
    }

    if(characterCode == 13){ //if generated character code is equal to ascii 13 (if enter key)
        return false;
    } else {
        return true;
    }
}

function clearHoldFor(){
	$.cookie("holdfor",null, { path: "/", expires: 0 });
}

function logOut(){
    if( typeof delBasket == 'function' ){
        delBasket('main', true);
    }
    clearHoldFor();
}

function openHelp(){
    openWindow("/cgi-bin/koha/help.pl","Koha help",600,600);
}

jQuery.fn.preventDoubleFormSubmit = function() {
    jQuery(this).submit(function() {
    $("body, form input[type='submit'], form button[type='submit'], form a").addClass('waiting');
        if (this.beenSubmitted)
            return false;
        else
            this.beenSubmitted = true;
    });
};

function openWindow(link,name,width,height) {
    name = (typeof name == "undefined")?'popup':name;
    width = (typeof width == "undefined")?'600':width;
    height = (typeof height == "undefined")?'400':height;
    var newin=window.open(link,name,'width='+width+',height='+height+',resizable=yes,toolbar=false,scrollbars=yes,top');
}

// Use this function to remove the focus from any element for
// repeated scanning actions on errors so the librarian doesn't
// continue scanning and miss the error.
function removeFocus() {
    $(':focus').blur();
}

function toUC(f) {
    var x=f.value.toUpperCase();
    f.value=x;
    return true;
}

function confirmDelete(message) {
    return (confirm(message) ? true : false);
}
