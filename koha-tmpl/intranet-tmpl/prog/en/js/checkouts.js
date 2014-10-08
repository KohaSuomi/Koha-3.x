$(document).ready(function() {
    $.ajaxSetup ({ cache: false });

    // Handle the select all/none links for checkouts table columns
    $("#CheckAllRenewals").on("click",function(){
        $("#UncheckAllCheckins").click();
        $(".renew:visible").attr("checked", "checked" );
        return false;
    });
    $("#UncheckAllRenewals").on("click",function(){
        $(".renew:visible").removeAttr("checked");
        return false;
    });

    $("#CheckAllCheckins").on("click",function(){
        $("#UncheckAllRenewals").click();
        $(".checkin:visible").attr("checked", "checked" );
        return false;
    });
    $("#UncheckAllCheckins").on("click",function(){
        $(".checkin:visible").removeAttr("checked");
        return false;
    });

    // Don't allow both return and renew checkboxes to be checked
    $(document).on("change", '.renew', function(){
        if ( $(this).is(":checked") ) {
            $( "#checkin_" + $(this).val() ).removeAttr("checked");
        }
    });
    $(document).on("change", '.checkin', function(){
        if ( $(this).is(":checked") ) {
            $( "#renew_" + $(this).val() ).removeAttr("checked");
        }
    });

    // Clicking the table cell checks the checkbox inside it
    $(document).on("click", 'td', function(e){
        if(e.target.tagName.toLowerCase() == 'td'){
          $(this).find("input:checkbox:visible").each( function() {
            $(this).click();
          });
        }
    });

    // Handle renewals and returns
    $("#RenewCheckinChecked").on("click",function(){
        $(".checkin:checked:visible").each(function() {
            itemnumber = $(this).val();

            $(this).replaceWith("<img id='checkin_" + itemnumber + "' src='" + interface + "/" + theme + "/img/loading-small.gif' />");

            params = {
                itemnumber:     itemnumber,
                borrowernumber: borrowernumber,
                branchcode:     branchcode,
                exempt_fine:    $("#exemptfine").is(':checked')
            };

            $.post( "/cgi-bin/koha/svc/checkin", params, function( data ) {
                id = "#checkin_" + data.itemnumber;

                content = "";
                if ( data.returned ) {
                    content = CIRCULATION_RETURNED;
                } else {
                    content = CIRCULATION_NOT_RETURNED;
                }

                $(id).replaceWith( content );
            }, "json")
        });

        $(".renew:checked:visible").each(function() {
            var override_limit = $("#override_limit").is(':checked') ? 1 : 0;

            var itemnumber = $(this).val();

            $(this).parent().parent().replaceWith("<img id='renew_" + itemnumber + "' src='" + interface + "/" + theme + "/img/loading-small.gif' />");

            var params = {
                itemnumber:     itemnumber,
                borrowernumber: borrowernumber,
                branchcode:     branchcode,
                override_limit: override_limit,
                date_due:       $("#newduedate").val()
            };

            $.post( "/cgi-bin/koha/svc/renew", params, function( data ) {
                var id = "#renew_" + data.itemnumber;

                var content = "";
                if ( data.renew_okay ) {
                    content = CIRCULATION_RENEWED_DUE + " " + data.date_due;
                } else {
                    content = CIRCULATION_RENEW_FAILED + " ";
                    if ( data.error == "no_checkout" ) {
                        content += NOT_CHECKED_OUT;
                    } else if ( data.error == "too_many" ) {
                        content += TOO_MANY_RENEWALS;
                    } else if ( data.error == "on_reserve" ) {
                        content += ON_RESERVE;
                    } else if ( data.error ) {
                        content += data.error;
                    } else {
                        content += REASON_UNKNOWN;
                    }
                }

                $(id).replaceWith( content );
            }, "json")
        });

        // Prevent form submit
        return false;
    });

    $("#RenewAll").on("click",function(){
        $("#CheckAllRenewals").click();
        $("#UncheckAllCheckins").click();
        $("#RenewCheckinChecked").click();

        // Prevent form submit
        return false;
    });

    var ymd = $.datepicker.formatDate('yy-mm-dd', new Date());

    var issuesTable;
    var drawn = 0;
    issuesTable = $("#issues-table").dataTable({
        "oLanguage": {
            "sEmptyTable" : MSG_DT_LOADING_RECORDS,
        },
        "bAutoWidth": false,
        "sDom": "<'row-fluid'<'span6'><'span6'>r>t<'row-fluid'>t",
        "aoColumns": [
            {
                "mDataProp": function( oObj ) {
                    if ( oObj.issued_today ) {
                        return "0";
                    } else {
                        return "100";
                    }
                }
            },
            {
                "mDataProp": function( oObj ) {
                    if ( oObj.issued_today ) {
                        return "<strong>" + TODAYS_CHECKOUTS + "</strong>";
                    } else {
                        return "<strong>" + PREVIOUS_CHECKOUTS + "</strong>";
                    }
                }
            },
            {
                "mDataProp": "date_due",
                "bVisible": false,
            },
            {
                "iDataSort": 1, // Sort on hidden unformatted date due column
                "mDataProp": function( oObj ) {
                    if ( oObj.date_due_overdue ) {
                        return "<span class='overdue'>" + oObj.date_due_formatted + "</span>";
                    } else {
                        return oObj.date_due_formatted;
                    }
                }
            },
            {
                "mDataProp": function ( oObj ) {
                    title = "<span class='strong'><a href='/cgi-bin/koha/catalogue/detail.pl?biblionumber="
                          + oObj.biblionumber
                          + "'>"
                          + oObj.title;

                    $.each(oObj.subtitle, function( index, value ) {
                              title += " " + value.subfield;
                    });

                    title += "</a></span>";

                    if ( oObj.author ) {
                        title += " " + BY.replace( "_AUTHOR_",  " " + oObj.author );
                    }

                    if ( oObj.itemnotes ) {
                        var span_class = "";
                        if ( $.datepicker.formatDate('yy-mm-dd', new Date(oObj.issuedate) ) == ymd ) {
                            span_class = "circ-hlt";
                        }
                        title += " - <span class='" + span_class + "'>" + oObj.itemnotes + "</span>"
                    }

                    title += " "
                          + "<a href='/cgi-bin/koha/catalogue/moredetail.pl?biblionumber="
                          + oObj.biblionumber
                          + "&itemnumber="
                          + oObj.itemnumber
                          + "#"
                          + oObj.itemnumber
                          + "'>"
                          + oObj.barcode
                          + "</a>";

                    return title;
                }
            },
            { "mDataProp": "itemtype" },
            { "mDataProp": "issuedate_formatted" },
            { "mDataProp": "branchname" },
            { "mDataProp": "itemcallnumber" },
            {
                "mDataProp": function ( oObj ) {
                    if ( ! oObj.charge ) oObj.charge = 0;
                    return parseFloat(oObj.charge).toFixed(2);
                }
            },
            {
                "mDataProp": function ( oObj ) {
                    if ( ! oObj.price ) oObj.price = 0;
                    return parseFloat(oObj.price).toFixed(2);
                }
            },
            {
                "bSortable": false,
                "mDataProp": function ( oObj ) {
                    var content = "";
                    var span_style = "";
                    var span_class = "";

                    content += "<span>";
                    content += "<span style='padding: 0 1em;'>" + oObj.renewals_count + "</span>";

                    if ( oObj.can_renew ) {
                        // Do nothing
                    } else if ( oObj.can_renew_error == "on_reserve" ) {
                        content += "<span class='renewals-disabled'>"
                                + "<a href='/cgi-bin/koha/reserve/request.pl?biblionumber=" + oObj.biblionumber + "'>" + ON_HOLD + "</a>"
                                + "</span>";

                        span_style = "display: none";
                        span_class = "renewals-allowed";
                    } else if ( oObj.can_renew_error == "too_many" ) {
                        content += "<span class='renewals-disabled'>"
                                + NOT_RENEWABLE
                                + "</span>";

                        span_style = "display: none";
                        span_class = "renewals-allowed";
                    } else if ( oObj.can_renew_error == "too_soon" ) {
                        content += "<span class='renewals-disabled'>"
                                + NOT_RENEWABLE_TOO_SOON.format( oObj.can_renew_date )
                                + "</span>";

                        span_style = "display: none";
                        span_class = "renewals-allowed";
                    } else {
                        content += "<span class='renewals-disabled'>"
                                + oObj.can_renew_error
                                + "</span>";

                        span_style = "display: none";
                        span_class = "renewals-allowed";
                    }

                    content += "<span class='" + span_class + "' style='" + span_style + "'>"
                            +  "<input type='checkbox' class='renew' id='renew_" + oObj.itemnumber + "' name='renew' value='" + oObj.itemnumber +"'/>"
                            +  "</span>";

                    if ( oObj.renewals_remaining ) {
                        content += "<span class='renewals'>("
                                + RENEWALS_REMAINING.format( oObj.renewals_remaining, oObj.renewals_allowed )
                                + ")</span>";
                    }

                    content += "</span>";


                    return content;
                }
            },
            {
                "bSortable": false,
                "mDataProp": function ( oObj ) {
                    if ( oObj.can_renew_error == "on_reserve" ) {
                        return "<a href='/cgi-bin/koha/reserve/request.pl?biblionumber=" + oObj.biblionumber + "'>" + ON_HOLD + "</a>";
                    } else {
                        return "<input type='checkbox' class='checkin' id='checkin_" + oObj.itemnumber + "' name='checkin' value='" + oObj.itemnumber +"'></input>";
                    }
                }
            },
            {
                "bVisible": exports_enabled ? true : false,
                "bSortable": false,
                "mDataProp": function ( oObj ) {
                    return "<input type='checkbox' class='export' id='export_" + oObj.biblionumber + "' name='biblionumbers' value='" + oObj.biblionumber + "' />";
                }
            }
        ],
        "fnFooterCallback": function ( nRow, aaData, iStart, iEnd, aiDisplay ) {
            var total_charge = 0;
            var total_price = 0;
            for ( var i=0; i < aaData.length; i++ ) {
                total_charge += aaData[i]['charge'] * 1;
                total_price  += aaData[i]['price'] * 1;
            }
            var nCells = nRow.getElementsByTagName('td');
            nCells[1].innerHTML = total_charge.toFixed(2);
            nCells[2].innerHTML = total_price.toFixed(2);
        },
        "bPaginate": false,
        "bProcessing": true,
        "bServerSide": false,
        "sAjaxSource": '/cgi-bin/koha/svc/checkouts',
        "fnServerData": function ( sSource, aoData, fnCallback ) {
            aoData.push( { "name": "borrowernumber", "value": borrowernumber } );

            $.getJSON( sSource, aoData, function (json) {
                fnCallback(json)
            } );
        },
        "fnInitComplete": function(oSettings) {
            // Disable rowGrouping plugin after first use
            // so any sorting on the table doesn't use it
            var oSettings = issuesTable.fnSettings();

            for (f = 0; f < oSettings.aoDrawCallback.length; f++) {
                if (oSettings.aoDrawCallback[f].sName == 'fnRowGrouping') {
                    oSettings.aoDrawCallback.splice(f, 1);
                    break;
                }
            }

            oSettings.aaSortingFixed = null;
        },
    }).rowGrouping(
        {
            iGroupingColumnIndex: 1,
            iGroupingOrderByColumnIndex: 0,
            sGroupingColumnSortDirection: "asc"
        }
    );

    if ( $("#issues-table").length ) {
        $("#issues-table_processing").position({
            of: $( "#issues-table" ),
            collision: "none"
        });
    }

    // Don't load relatives' issues table unless it is clicked on
    var relativesIssuesTable;
    $("#relatives-issues-tab").click( function() {
        if ( ! relativesIssuesTable ) {
            relativesIssuesTable = $("#relatives-issues-table").dataTable({
                "bAutoWidth": false,
                "sDom": "<'row-fluid'<'span6'><'span6'>r>t<'row-fluid'>t",
                "aaSorting": [],
                "aoColumns": [
                    {
                        "mDataProp": "date_due",
                        "bVisible": false,
                    },
                    {
                        "iDataSort": 1, // Sort on hidden unformatted date due column
                        "mDataProp": function( oObj ) {
                            var today = new Date();
                            var due = new Date( oObj.date_due );
                            if ( today > due ) {
                                return "<span class='overdue'>" + oObj.date_due_formatted + "</span>";
                            } else {
                                return oObj.date_due_formatted;
                            }
                        }
                    },
                    {
                        "mDataProp": function ( oObj ) {
                            title = "<span class='strong'><a href='/cgi-bin/koha/catalogue/detail.pl?biblionumber="
                                  + oObj.biblionumber
                                  + "'>"
                                  + oObj.title;

                            $.each(oObj.subtitle, function( index, value ) {
                                      title += " " + value.subfield;
                            });

                            title += "</a></span>";

                            if ( oObj.author ) {
                                title += " " + BY + " " + oObj.author;
                            }

                            if ( oObj.itemnotes ) {
                                var span_class = "";
                                if ( $.datepicker.formatDate('yy-mm-dd', new Date(oObj.issuedate) ) == ymd ) {
                                    span_class = "circ-hlt";
                                }
                                title += " - <span class='" + span_class + "'>" + oObj.itemnotes + "</span>"
                            }

                            title += " "
                                  + "<a href='/cgi-bin/koha/catalogue/moredetail.pl?biblionumber="
                                  + oObj.biblionumber
                                  + "&itemnumber="
                                  + oObj.itemnumber
                                  + "#"
                                  + oObj.itemnumber
                                  + "'>"
                                  + oObj.barcode
                                  + "</a>";

                            return title;
                        }
                    },
                    { "mDataProp": "itemtype" },
                    { "mDataProp": "issuedate_formatted" },
                    { "mDataProp": "branchname" },
                    { "mDataProp": "itemcallnumber" },
                    {
                        "mDataProp": function ( oObj ) {
                            if ( ! oObj.charge ) oObj.charge = 0;
                            return parseFloat(oObj.charge).toFixed(2);
                        }
                    },
                    {
                        "mDataProp": function ( oObj ) {
                            if ( ! oObj.price ) oObj.price = 0;
                            return parseFloat(oObj.price).toFixed(2);
                        }
                    },
                    {
                        "mDataProp": function( oObj ) {
                            return "<a href='/cgi-bin/koha/members/moremember.pl?borrowernumber=" + oObj.borrowernumber + "'>"
                                 + oObj.borrower.firstname + " " + oObj.borrower.surname + " (" + oObj.borrower.cardnumber + ")</a>"
                        }
                    },
                ],
                "bPaginate": false,
                "bProcessing": true,
                "bServerSide": false,
                "sAjaxSource": '/cgi-bin/koha/svc/checkouts',
                "fnServerData": function ( sSource, aoData, fnCallback ) {
                    $.each(relatives_borrowernumbers, function( index, value ) {
                        aoData.push( { "name": "borrowernumber", "value": value } );
                    });

                    $.getJSON( sSource, aoData, function (json) {
                        fnCallback(json)
                    } );
                },
            });
        }
    });

    if ( $("#relatives-issues-table").length ) {
        $("#relatives-issues-table_processing").position({
            of: $( "#relatives-issues-table" ),
            collision: "none"
        });
    }

    if ( AllowRenewalLimitOverride ) {
        $( '#override_limit' ).click( function () {
            if ( this.checked ) {
                $( '.renewals-allowed' ).show(); $( '.renewals-disabled' ).hide();
            } else {
                $( '.renewals-allowed' ).hide(); $( '.renewals-disabled' ).show();
            }
        } ).attr( 'checked', false );
    }
 });
