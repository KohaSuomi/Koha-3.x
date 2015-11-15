//Package Items.ItemsTableRow
if (typeof Items == "undefined") {
    this.Items = {}; //Set the global package
}

if (typeof Items.ItemsTableView == "undefined") {
    this.Items.ItemsTableView = {}; //Set the global package
}

Items.ItemsTableView.template = function () {
    var html = ""+
    '<thead>'+
    '    <tr>'+
    '        <th></th>'+
    '        <th>Item type</th>'+
    '        <th>Current location</th>'+
    '        <th>Home library</th>'+
    '        <th>Collection</th>'+
    '        <th>Call number</th>'+
    '        <th>Status</th>'+
    '        <th>Last seen</th>'+
    '        <th>Barcode</th>'+
    '        <th>Publication details</th>'+
    '        <th>url</th>'+
    '        <th>Copy number</th>'+
    '        <th>Materials specified</th>'+
    '        <th>Public notes</th>'+
    '        <th>Spine label</th>'+
    '        <th>Host records</th>'+
    '        <th>Edit</th>'+
    '    </tr>'+
    '</thead>'+
    '<tbody>'+
    '</tbody>';
    return html;
}

//Introducing some kind of a petit templating javascript unigine.
Items.ItemsTableRowTmpl = {
    ItemsTableRowTmpl: function (item) {
        this.element = Items.ItemsTableRowTmpl.getTableRow(item);
        /**
         * Implements the Subscriber-Publisher pattern.
         * Receives a publication from the Publisher.
         */
        this.publish = function(publisher, data, event) {
            if (event == "place_hold_succeeded") {
                Items.ItemsTableRowTmpl.displayPlaceHoldSucceeded(this, publisher, data);
            }
            if (event == "place_hold_failed") {
                Items.ItemsTableRowTmpl.displayPlaceHoldFailed(this, publisher, data);
            }
        };
    },
    transform: function (item) {
        return [
            '<input id="'+Items.ItemsTableRowTmpl.getId(item)+'" value="'+item.itemnumber+'" name="itemnumber" type="checkbox">',
            '<img src="/intranet-tmpl/prog/img/itemtypeimg/bridge/periodical.gif" alt="'+item.c_itype+'" title="'+item.c_itype+'">',
            (item.c_holdingbranch ? item.c_holdingbranch : ''),
            item.c_homebranch+'<span class="shelvingloc">'+item.c_location+'</span>',
            (item.c_ccode ? item.c_ccode : ''),
            (item.itemcallnumber ? item.itemcallnumber : ''),
            Items.getAvailability(item),
            (item.datelastseen ? item.datelastseen : ''),
            (item.barcode ? '<a href="/cgi-bin/koha/catalogue/moredetail.pl?type=&amp;itemnumber='+item.itemnumber+'&amp;biblionumber='+item.biblionumber+'&amp;bi='+item.biblioitemnumber+'#item'+item.itemnumber+'">'+item.barcode+'</a>' : ""),
            (item.enumchron ? item.enumchron+' <span class="pubdate">('+item.publisheddate+')</span>' : ""),
            (item.uri ? item.uri : ''),
            (item.copynumber ? item.copynumber : ''),
            (item.materials ? item.materials : ''),
            (item.itemnotes ? item.itemnotes : ''),
            '<a href="/cgi-bin/koha/labels/spinelabel-print.pl?barcode='+item.barcode+'" >Print label</a>',
            ( item.hostbiblionumber ? '<a href="/cgi-bin/koha/catalogue/detail.pl?biblionumber='+item.hostbiblionumber+'" >'+item.hosttitle+'</a>' : ''),
            '<a href="/cgi-bin/koha/cataloguing/additem.pl?op=edititem&amp;biblionumber='+item.biblionumber+'&amp;itemnumber='+item.itemnumber+'#edititem">Edit</a><br/>'+
                '<button class="placeHold" onclick="holdPicker.selectItem('+item.itemnumber+')">Hold</button>',
        ];
    },
    getSelector: function (item) {
        return "#"+Items.ItemsTableRowTmpl.getId(item);
    },
    getTableRow: function (item) {
        return $(Items.ItemsTableRowTmpl.getSelector(item)).parents("tr");
    },
    getId: function (item) {
        return "itr_"+item.itemnumber;
    },
    displayPlaceHoldSucceeded: function (self, publisher, item) {
        $(self.element).find("button.placeHold").parent().append("<br/><span class='notification' style='color: #00AA00;'>Hold placed</span>");
    },
    displayPlaceHoldFailed: function (self, publisher, errorObject) {
        $(self.element).find("button.placeHold").parent().append("<br/><span class='notification' style='color: #AA0000;'>"+errorObject.error+"</span>");
    }
};