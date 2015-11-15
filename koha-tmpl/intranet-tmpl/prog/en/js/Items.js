//Package Items
if (typeof Items == "undefined") {
    this.Items = {}; //Set the global package
}

/**
 * Resolves the availability of the given Item and returns a nice html-representation of the Item's availability statuses.
 */
Items.getAvailability = function (item) {

    var html = "";

    if (item.date_due) {
        html +=
        '<span class="datedue">Checked out to <a href="/cgi-bin/koha/members/moremember.pl?borrowernumber='+item.iss_borrowernumber+'">'+
        item.iss_cardnumber+'</a> : due '+item.iss_date_due+"</span>";
    }
    if (item.transfertwhen) {
        html +=
        '<span class="intransit">In transit from '+item.transfertfrom+' to '+item.transfertto+' since '+item.transfertwhen+"</span>";
    }
    if (item.c_withdrawn) {
        html +=
        '<span class="wdn">Withdrawn</span>';
    }
    if (item.c_notforloan) {
        html +=
        '<span>Not for loan'+(item.c_notforloan ? ' ('+item.c_notforloan+')' : "");
    }
    if (item.res_borrowernumber) {
        html +=
        '<span>Hold for <a href="/cgi-bin/koha/members/moremember.pl?borrowernumber='+item.res_borrowernumber+'">'+item.res_cardnumber+'</a></span>';
    }
    if (item.res_waitingdate) {
        html +=
        '<span>Hold waiting since '+item.res_waitingdate+'</span>';
    }
    if (item.restricted) {
        html +=
        '<span class="restricted">('+item.restricted+')</span>';
    }
    if (item.c_itemlost) {
        html +=
        '<span class="lost">('+item.c_itemlost+')</span>';
    }
    if (item.c_damaged) {
        html +=
        '<span class="dmg">('+item.c_damaged+')</span>';
    }
    if (html.length == 0) {
        html +=
        '<span>Available</span>';
    }

    return html;
}

/**
 * Adds a Subscriber to the events of this Item. When events occur,
 * Item calls the publish()-function of the Listener with the following parameters:
 *        {Item} this object which initiated the call.
 *        {data} data related to the event
 *        {event} data related to the event.
 *
 * @param {Item-object} this Publisher-object
 * @param {Listener-object} Any object which is configured to subscribe to a Item
 */
Items.subscribe = function(item, subscriber) {
    if (!item._subscribers) {
        item._subscribers = [];
    }
    item._subscribers.push( subscriber );
}
Items.unsubscribe = function(item, subscriber) {
    for (var i=0 ; i<item._subscribers.length ; i++) {
        var subscribingSubscriber = item._subscribers[i];
        if (subscriber === subscribingSubscriber) {
            item._subscribers.splice(i,1);
            break;
        }
    }
}
/**
 * Publishes a publication to all subscribers.
 */
Items.publicate = function (item, data, event) {
    for (var i=0 ; i<item._subscribers.length ; i++) {
        var subscriber = item._subscribers[i];
        subscriber.publish(item, data, event );
    }
}



//Package Items.Cache
if (typeof Items.Cache == "undefined") {
    this.Items.Cache = {}; //Set the global package
}

Items.Cache.map = {};
/**
 * Gets an Item from the local cache.
 * @param {Int} itemnumber
 */
Items.Cache.getLocalItem = function (itemnumber) {
    return Items.Cache.map[itemnumber];
}

/**
 * Adds an Item to the local cache.
 * @param {Item}
 */
Items.Cache.addLocalItem = function (item) {
    Items.Cache.map[item.itemnumber] = item;
}

/**
 * Adds a set of Items to the local cache.
 * @param {Array|Map of Items}
 */
Items.Cache.addLocalItems = function (items) {
    for(var key in items) {
        var item = items[key];
        Items.Cache.map[item.itemnumber] = item;
    }
}

/**
 * Clears the cache or a single Item from it.
 * @param {Int} itemnumber
 */
Items.Cache.clear = function (itemnumber) {
    if (itemnumber) {
        delete Items.Cache.map[itemnumber];
    }
    else {
        Items.Cache.map = {};
    }
}