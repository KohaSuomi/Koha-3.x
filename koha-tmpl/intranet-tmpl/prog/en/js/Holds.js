//Package Holds
if (typeof Holds == "undefined") {
    this.Holds = {}; //Set the global package
}
var log = log;
if (!log) {
    log = log4javascript.getDefaultLogger();
}

Holds.placeHold = function (item, borrower, pickupBranch, biblio, expirationdate, suspend_until) {
    if (!item || !item.itemnumber) {
        log.error("Holds.placeHold():> No Item!");
        return;
    }
    if (!borrower || !borrower.borrowernumber) {
        log.error("Holds.placeHold():> No Borrower!");
        return;
    }
    if (!pickupBranch || !pickupBranch.branchcode) {
        log.error("Holds.placeHold():> No Pickup Branch!");
        return;
    }

    //Build the request parameters
    var requestBody = {};
    if (biblio) {
        requestBody.biblionumber   = parseInt(biblio.biblionumber);
    }
    if (item) {
        requestBody.itemnumber     = parseInt(item.itemnumber);
    }
    if (borrower) {
        requestBody.borrowernumber = parseInt(borrower.borrowernumber);
    }
    if (pickupBranch) {
        requestBody.branchcode     = pickupBranch.branchcode;
    }
    if (expirationdate) {
        requestBody.expirationdate = expirationdate;
    }
    if (suspend_until) {
        requestBody.suspend_until  = suspend_until;
    }

    $.ajax("/api/v1/borrowers/"+borrower.borrowernumber+"/holds",
        { "method": "POST",
          "accepts": "application/json",
          "contentType": "application/json; charset=utf8",
          "processData": false,
          "data": JSON.stringify(requestBody),
          "success": function (jqXHR, textStatus, errorThrown) {
            var hold = jqXHR;

            if (hold.itemnumber) {
                var item = Items.Cache.getLocalItem(hold.itemnumber);
                Items.publicate(item, hold, 'place_hold_succeeded');
            }
//            //You can extend the publication targets here.
//            if (hold.biblionumber) {
//                var biblio = Biblios.Cache.getLocalBiblio(hold.biblionumber);
//                Biblios.publicate(biblio, hold, 'place_hold_succeeded');
//            }
          },
          "error": function (jqXHR, textStatus, errorThrown) {
            var responseObject = JSON.parse(jqXHR.responseText);
            if (requestBody.itemnumber) { //See if this ajax-call was called with an Item.
                var item = Items.Cache.getLocalItem( requestBody.itemnumber );
                Items.publicate(item, responseObject, 'place_hold_failed');
            }
//            //You can extend the publication targets here.
//            if (requestBody.biblionumber) {
//                var biblio = Biblios.Cache.getLocalBiblio(hold.biblionumber);
//                Biblios.publicate(biblio, responseObject, 'place_hold_failed');
//            }
            else {
                alert(textStatus+" "+(responseObject ? responseObject.error : errorThrown));
            }
          },
        }
    );
}



//Package Holds.HoldsPicker

/**
 * var holdPicker = new Holds.HoldPicker(params);
 * @param {Object} params, parameters as an object, valid attributes:
 *            {Object} 'biblio' - The Biblio-object the holds are targeted at.
 *            {Object} 'item' - The Item-object the holds are tergeted at.
 *            {Object} 'borrower' - The Borrower who is receiving the Hold
 *            {String ISO8601 Date} 'suspend_until' - Activate the Hold after this date.
 *            {String} 'pickupBranch' - Where the Borrower wants the Item delivered.
 */
Holds.HoldPicker = function (params) {
    params = (params ? params : {});
    var self = this; //Create a closure-variable to pass to event handler.
    this.biblio = params.biblio;
    this.item = params.item;
    this.borrower = params.borrower;
    this.suspend_until = params.suspend_until;
    this.pickupBranch = params.pickupBranch;

    this._template = function () {
        var html =
        '<fieldset id="holdPicker" style="position: absolute; width: 200px; right: 75px;">'+
        '  <legend>Hold Picker</legend>'+
        '  <div class="biblioInfo"></div><button id="hp_exit" style="position: absolute; top: -10px; right: 4px;"> X </button>'+
        '  <br/><span class="borrowerInfo"></span>'+
        '  <br/><input id="hp_cardnumber" type="text" width="16"/>'+
        '  <div id="hp_datepicker"></div>'+
        Branches.getBranchSelectorHtml({}, "hp_pickupBranches")+
        '  <span class="result"></span>'+
        '  <button id="hp_placeHold">Place Hold</button><button id="hp_clear">Clear</button>'+
        '</fieldset>'+
        '';
        return $(html);
    }
    this.getBiblioElement = function () {
        return $(this.rootElement).find(".biblioInfo");
    }
    this.clearBiblioElement = function () {
        var ie = this.getBiblioElement();
        ie.html("");
    }
    this.getBorrowerInfoElement = function () {
        return $(this.rootElement).find(".borrowerInfo");
    }
    this.getExitElement = function () {
        return $(this.rootElement).find("#hp_exit");
    }
    this.getCardnumberElement = function () {
        return $(this.rootElement).find("#hp_cardnumber");
    }
    this.clearCardnumber = function () {
        var ce = this.getCardnumberElement();
        ce.val("");
        this.borrower = null;
        this.renderBorrower();
    }
    this.setBorrower = function (borrower) {
        this.borrower = borrower;
    }
    this.getDatepickerElement = function () {
        return $(this.rootElement).find("#hp_datepicker");
    }
    this.clearDatepicker = function () {
        var de = this.getDatepickerElement();
        de.val("");
        this.suspend_until = null;
    }
    this.getPickupBranchesElement = function () {
        return $(this.rootElement).find("#hp_pickupBranches");
    }
    this.clearPickupBranch = function () {
        var pe = this.getPickupBranchesElement();
        pe.val("");
        this.pickupBranch = null;
    }
    this.getResultElement = function () {
        return $(this.rootElement).find(".result");
    }
    this.setResult = function (result) {
        var re = this.getResultElement();
        re.html(result);
    }
    this.getPlaceHoldElement = function () {
        return $(this.rootElement).find("#hp_placeHold");
    }
    this.placeHold = function () {
        Holds.placeHold(this.item, this.borrower, this.pickupBranch, this.biblio, null, this.suspend_until);
    }
    this.getClearElement = function () {
        return $(this.rootElement).find("#hp_clear");
    }
    this.clear = function () {
        this.clearCardnumber();
        this.clearDatepicker();
        this.clearPickupBranch();
        this.clearBiblioElement();
        this.biblio = null;
        this.item = null;
        this.hide();
    }
    this.render = function () {
        this.renderBiblio();
        this.renderBorrower();
    }
    this.renderBiblio = function () {
        var ie = this.getBiblioElement();
        var html = "";
        if (this.biblio) {
            html +=
            '<span class="title">'+
                (this.biblio.title ? this.biblio.title : this.biblio.biblionumber)+" "+
            '</span>';
        }
        if (this.item) {
            html +=
            '<span>'+
                (this.item.barcode ? this.item.barcode : "")+" "+
                (this.item.enumchron ? this.item.enumchron : "")+
            '</span>';
        }
        $(ie).html(html);
    }
    this.renderBorrower = function () {
        var be = this.getBorrowerInfoElement();
        if (!this.borrower) {
            $(be).html('');
        }
        else {
            $(be).html(
                (this.borrower.cardnumber ? this.borrower.cardnumber : this.borrower.borrowernumber)+' '+
                (this.borrower.surname ? this.borrower.surname : '')+' '+
                (this.borrower.firstname ? this.borrower.surname : '')
            );
            this.getCardnumberElement().val((this.borrower.cardnumber ? this.borrower.cardnumber : ''));
        }
    }
    this.selectItem = function (itemnumber) {
        this.item = Items.Cache.getLocalItem(itemnumber);
        var tableRow = $(Items.ItemsTableRowTmpl.getTableRow(this.item));
        self.alignToElement(tableRow);
        this.renderBiblio();
        $(this.rootElement).draggable();
        if ($(self.rootElement).is(':hidden')) {
            $(self.rootElement).show(5);
        }
    }
    this.alignToElement = function (jq_element) {
        $(self.rootElement).appendTo(jq_element);
    }
    this.hide = function () {
        $(self.rootElement).hide(500, function () {
            $(self.rootElement).draggable("destroy").css("left","").css("top","");
        });
    }
    this._bindEvents = function () {
        this.getExitElement().bind({
            "click": function (event) {
                self.hide();
            }
        });
        this.getClearElement().bind({
            "click": function (event) {
                self.clear(this, event);
            }
        });
        this.getPlaceHoldElement().bind({
            "click": function (event) {
                self.placeHold();
            }
        });
        this.getPickupBranchesElement().bind({
            "change": function (event) {
                self.pickupBranch = {branchcode: $(this).val()};
            }
        });
        this.getCardnumberElement().bind({
            "change": function (event) {
                var searchTerm = self.getCardnumberElement().val();
                Borrowers.getBorrowers({cardnumber: searchTerm,
                                        userid: searchTerm,
                                    }, function (jqXHR, textStatus, errorThrown) {
                    if (String(errorThrown.status).search(/^2\d\d/) >= 0) { //Status is OK
                        self.setBorrower(jqXHR[0]);
                    }
                    else {
                        self.setBorrower(null)
                    }
                    self.renderBorrower();
                });
            }
        });
    }

    this.rootElement = this._template();
    this._bindEvents(this.rootElement);
    this.render();
    $(this.rootElement).hide(); //If the element is not attached to anything, it is neither considered :hidden or :visible.
    $(this.rootElement).appendTo('body').draggable();


    return this;
}