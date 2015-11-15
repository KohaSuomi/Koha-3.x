//Package Branches
if (typeof Branches == "undefined") {
    this.Branches = {}; //Set the global package
}

var log = log;
if (!log) {
    log = log4javascript.getDefaultLogger();
}

Branches.branchSelectorHtml = null; //The unattached template
Branches.getBranchSelectorHtml = function (branches, id) {
    var bSelector = Branches.getCachedBranchSelectorHtml(branches, id);
    if (!bSelector) {
        bSelector = Branches.createBranchSelectorHtml(branches, id);
    }
    return Branches.rebrandBranchSelectorHtml(bSelector, id);
}
Branches.createBranchSelectorHtml = function (branches, id) {
    var bSelectorHtml = Branches.BranchSelectorTmpl.transform(branches, id);
    Branches.cacheBranchSelectorHtml(bSelectorHtml, id);
    return bSelectorHtml;
}
Branches.cacheBranchSelectorHtml = function (branchSelector, id) {
    Branches.branchSelector = branchSelector;
}
Branches.getCachedBranchSelectorHtml = function (branchSelector, id) {
    return Branches.branchSelector;
}
Branches.rebrandBranchSelectorHtml = function (branchSelectorHtml, id) {
    return branchSelectorHtml.replace('id="branchSelectorTemplate"', 'id="'+id+'"');
}



//Package Branches.BranchSelectorTmpl
if (typeof Branches.BranchSelectorTmpl == "undefined") {
    this.Branches.BranchSelectorTmpl = {}; //Set the global package
}

/**
 * @returns {String HTML} the unattached HTML making up the BranchSelector.
 */
Branches.BranchSelectorTmpl.transform = function (branches) {
    var html =
    '<select size="1" id="branchSelectorTemplate">';
    for (var i=0 ; i<branches.length ; i++) { var branch = branches[i];
        html +=
        '<option value="'+branch.branchcode+'" '+(branch.selected ? 'selected="selected"' : '')+'>'+branch.branchname+'</option>';
    }
    html +=
    '</select>';
    return html;
}