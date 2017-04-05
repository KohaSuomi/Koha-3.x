
function Report(){
    var self = this;
    self.name = ko.observable('');
    self.description = ko.observable('');
    self.group = ko.observable('');
    self.groupings = ko.observableArray([]);
    self.filters = ko.observableArray();
    self.orderings = ko.observableArray([]);
    self.orderingsHash = {};
    self.visibleOrderings = ko.observableArray([]);
    self.selectedOrdering = ko.observable('');
    self.selectedDirection = ko.observable('asc');
    self.limit = ko.observable('');
    self.hasTopLimit = ko.observable(1);
    self.renderedReport = ko.observable('');
    self.selectedReportType = ko.observable('html');

    self.formatDate = function(date){
        var dateFormat = "dd.MM.yyyy";
        var formatedDate = date.toString(dateFormat);
        return formatedDate;
    };

    self.toJSON = function() {
        var report = ko.toJS(self);
        if(report.hasOwnProperty('filters') && report.filters.length > 0){
            var filtersLength = report.filters.length;
            var filters = report.filters;
            report.filters = [];
            report.renderedReport = '';
            for (var i = 0; i < filtersLength; i++) {
                var filter = filters[i];
                if(filter && filter.selectedOptions.length > 0 || filter.selectedValue1  || filter.selectedValue2 ){
                    filter.options = [];
                    report.filters.push(filter);
                }
            }
        }
        if(report.hasOwnProperty('groupings') && report.groupings.length > 0){
            var groupingsLength = report.groupings.length;
            var groupings = report.groupings;
            report.groupings = [];
            for (var j = 0; j < groupingsLength; j++) {
                var grouping = groupings[j];
                if(grouping && grouping.selectedValue == true ){
                    report.groupings.push(grouping);
                }
            }
        }
        return report;
    }

    self.toDropdownOption = function () {
        return { text: self.description(), value: self.name(), original: self };
    };

    var date = new Date();
    var startDate = new Date(date.getFullYear(), date.getMonth(), 1);
    var endDate = new Date(date.getFullYear(), date.getMonth() + 1, 0);

    self.dateFilter = ko.observable({
        'useTo': ko.observable(1) ,
        'useFrom': ko.observable(1),
        'showPrecision': ko.observable(0),
        'from': ko.observable(self.formatDate(startDate)),
        'to': ko.observable(self.formatDate(endDate)),
        'precision': ko.observable('month')
    });
};

function Filter(){
    var self = this;
    self.name = ko.observable();
    self.description = ko.observable();
    self.type;
    self.options = ko.observableArray([]);
    self.selectedOptions = ko.observableArray([]);
    self.selectedValue1 = ko.observable('');
    self.selectedValue2 = ko.observable('');
}

function Grouping(){
    var self = this;
    self.name = ko.observable();
    self.description = ko.observable();
    self.selectedValue = ko.observable(false);
    self.selectedOptions = ko.observable('');
    self.showOptions = ko.observable(0);
}

function Ordering(){
    var self = this;
    self.name = ko.observable();
    self.selected = ko.observable();
}

function ReportingView() {
    var self = this;
    self.formId = 'reporting-main-form';
    
    self.reportFactory = new ReportFactory();
    self.reports = ko.observableArray([]);
    self.reportGroups = ko.observableArray([]);
    self.selectedReportGroup = ko.observable();
    self.selectedReport = ko.observable({filters: ko.observableArray([{type : 'text'}])});
    self.htmlSpinnerVisible = ko.observable(0);
    self.csvSpinnerVisible = ko.observable(0);

    self.reportSubmit = function(){
       if(self.selectedReport().selectedReportType() == 'html'){
           self.renderReport();
       }
       else{
           var requestJson = self.generateRequestJson();

           if(!$('#request_json').length){
               var input = $("<input id='request_json' name='request_json' type='hidden'>");
               $('#reporting-main-form').append(input);
           }

           $('#request_json').val(requestJson);
           $('#reporting-main-form').submit();
       }
    };

    self.generateRequestJson = function(){
        var report = self.selectedReport();
        var jsonData = ko.toJSON(report);
        return jsonData;
    };

    self.reportSubmitHtml = function(){
        self.htmlSpinnerVisible(1);
        self.selectedReport().selectedReportType('html');
        self.reportSubmit();
    };

    self.reportSubmitCsv = function(){
        self.selectedReport().selectedReportType('csv');
        self.reportSubmit();
    };

    self.renderReport = function(){
        var requestJson = self.generateRequestJson();
        var response = '';
        jQuery.ajax({
           url: 'request.pl',
           data: {
                'request_json': requestJson
           },
           type: "POST",

           success: function( ajaxResponse ) {
               response = ajaxResponse;
               self.htmlSpinnerVisible(0);
               self.selectedReport().renderedReport(response);
           },
           error: function( xhr, status, errorThrown ) {
               console.log(status);
               self.htmlSpinnerVisible(0);
               response = xhr.responseText;
               self.selectedReport().renderedReport(response);
           },
           complete: function( xhr, status ) {
  
           }
        }); 
    };

    self.groupByChecked = function(grouping){
        if(grouping && grouping.hasOwnProperty('name')){
            var name = grouping.name();
            var report = self.selectedReport();
            var isChecked = grouping.selectedValue();
            var visibleOrdering = self.getVisibleOrderingByName(name, report);

            if(visibleOrdering && isChecked == false){
               report.visibleOrderings.remove(visibleOrdering);
            }
            else if(!visibleOrdering && report.orderingsHash.hasOwnProperty(name) && isChecked == true){
               var index = report.orderingsHash[name];
               var ordering = report.orderings()[index];
               report.visibleOrderings.push(ordering);
            }
        }

        return true;
    };

    self.getVisibleOrderingByName = function(name, report){
        var ordering;
        var orderingsLength = report.visibleOrderings().length;
        if(name && orderingsLength > 0){
            for (var i = 0; i < orderingsLength; i++) {
               var tmpOrdering = report.visibleOrderings()[i];
               if(tmpOrdering.name() == name){
                  ordering = tmpOrdering;
                  break;
               }
            }
        }
        return ordering;
    };

    self.filterClear = function(index){
        var length = index + 1; 
        var result = false;
        if(length != 0 && length %3 == 0){
            result = true;
        }
        return result;
    }

    self.init = function(){
        self.initDatePicker();
        var groups = self.reportFactory.createReportsFromJson();
        if(groups){
           self.reportGroups(groups);
        }
        self.selectedReportGroup(self.reportGroups()[0]);
        self.selectedReport(self.selectedReportGroup().reports()[0]);
    };

    self.initDatePicker = function() {
        $( function() {
        var dateFormat = "dd.mm.yy",
        from = $( "#from" ).datepicker({
            dateFormat: dateFormat,
            changeMonth: true,
            numberOfMonths: 1
        }).on( "change", function() {
          to.datepicker( "option", "minDate", getDate( this ) );
        }),
        to = $( "#to" ).datepicker({
            dateFormat: dateFormat,
            changeMonth: true,
            numberOfMonths: 1
        })
        .on( "change", function() {
            from.datepicker( "option", "maxDate", getDate( this ) );
        });

        function getDate( element ) {
            var date;
            try {
                date = $.datepicker.parseDate( dateFormat, element.value );
            } catch( error ) {
                date = null;
            }
            return date;
        }
        } );
    }

    self.init();

    self.orderLimitVisible = ko.computed(function() {
        var result = false;
        if(self.selectedReport().visibleOrderings.length > 0 || self.selectedReport().hasTopLimit() == '1'){
            result = true;
        }
        return result;
    }, self);

};


function ReportFactory(){
    var self = this;
    
    self.createReportsFromJson = function(){
        var json = JSON.parse(reportDataJson);
        var jsonLength = json.length;
        var reportGroups = [];
        var reportGroupsHash = {};
        if(json && jsonLength > 0){
            for (var i = 0; i < jsonLength; i++) { 
                var reportData = json[i];
                var report = new Report();
                if(reportData.hasOwnProperty('name')){
                    report.name(reportData['name']);
                }
                if(reportData.hasOwnProperty('description')){
                    report.description(reportData['description']);
                }
                if(reportData.hasOwnProperty('use_date_from')){
                    report.dateFilter().useFrom(reportData['use_date_from']);
                }
                if(reportData.hasOwnProperty('use_date_to')){
                    report.dateFilter().useTo(reportData['use_date_to']);
                }
                if(reportData.hasOwnProperty('groupings')){
                    var groupingsLength = reportData.groupings.length;
                    if(groupingsLength > 0){
                        for (var k = 0; k < groupingsLength; k++) {
                            var grouping = new Grouping();
                            var groupingData = reportData.groupings[k];
                            if(groupingData.hasOwnProperty('name')){
                                grouping.name(groupingData['name']);
                            }
                            if(groupingData.hasOwnProperty('description')){
                                grouping.description(groupingData['description']);
                            }
                            if(groupingData.hasOwnProperty('show_options')){
                                grouping.showOptions(groupingData['show_options']);
                            }
                            report.groupings.push(grouping);
                        }
                    } 
                }
                if(reportData.hasOwnProperty('filters')){
                    var filtersLength = reportData.filters.length;
                    if(filtersLength > 0){
                        for (var j = 0; j < filtersLength; j++) {
                            var filter = new Filter();
                            var filterData = reportData.filters[j];
                            if(filterData.hasOwnProperty('name')){
                                filter.name(filterData['name']);
                            }
                            if(filterData.hasOwnProperty('description')){
                                filter.description(filterData['description']);
                            }
                            if(filterData.hasOwnProperty('type')){
                                filter.type = filterData['type'];
                            }
                            if(filterData.hasOwnProperty('options')){
                                filter.options(filterData['options']);
                            }
                            report.filters.push(filter);
                        }
                    }
                }
                if(reportData.hasOwnProperty('orderings')){
                    var orderingsLength = reportData.orderings.length;
                    if(orderingsLength > 0){
                        for (var l = 0; l < orderingsLength; l++) {
                            var orderingData = reportData.orderings[l];
                            var ordering = new Ordering();
                            ordering.name(orderingData['name']);
                            report.orderings.push(ordering);
                            var index = report.orderings().length -1;
                            report.orderingsHash[ordering.name()] = index;
                        }
                    }
                }
                if(reportData.hasOwnProperty('group')){
                    report.group(reportData['group']);
                    var reportGroup;
                    if(reportGroupsHash.hasOwnProperty(report.group())){
                        reportGroup = reportGroups[reportGroupsHash[report.group()]];
                    }
                    else{
                        reportGroup = {name:report.group(), reports:ko.observableArray()};
                        reportGroups.push(reportGroup);
                        reportGroupsHash[report.group()] = reportGroups.length -1;
                    }
                    
                    reportGroup.reports.push(report);
                }
            }
        }
        return reportGroups;
    }


 ko.bindingHandlers.selectPicker = {
     init: function (element, valueAccessor, allBindingsAccessor) {
         if ($(element).is('select')) {
             if (ko.isObservable(valueAccessor())) {
                 if ($(element).prop('multiple') && $.isArray(ko.utils.unwrapObservable(valueAccessor()))) {
                     // in the case of a multiple select where the valueAccessor() is an observableArray, call the default Knockout selectedOptions binding
                     ko.bindingHandlers.selectedOptions.init(element, valueAccessor, allBindingsAccessor);
                 } else {
                     // regular select and observable so call the default value binding
                     ko.bindingHandlers.value.init(element, valueAccessor, allBindingsAccessor);
                 }
             }
             $(element).addClass('selectpicker').selectpicker();
         }
     },
     update: function (element, valueAccessor, allBindingsAccessor) {
         if ($(element).is('select')) {
             var selectPickerOptions = allBindingsAccessor().selectPickerOptions;
             if (typeof selectPickerOptions !== 'undefined' && selectPickerOptions !== null) {
                 var options = selectPickerOptions.optionsArray,
                     optionsText = selectPickerOptions.optionsText,
                     optionsValue = selectPickerOptions.optionsValue,
                     optionsCaption = selectPickerOptions.optionsCaption,
                     isDisabled = selectPickerOptions.disabledCondition || false,
                     resetOnDisabled = selectPickerOptions.resetOnDisabled || false;
                 if (ko.utils.unwrapObservable(options).length > 0) {
                     // call the default Knockout options binding
                     ko.bindingHandlers.options.update(element, options, allBindingsAccessor);
                 }
                 if (isDisabled && resetOnDisabled) {
                     // the dropdown is disabled and we need to reset it to its first option
                     $(element).selectpicker('val', $(element).children('option:first').val());
                 }
                 $(element).prop('disabled', isDisabled);
             }
             if (ko.isObservable(valueAccessor())) {
                 if ($(element).prop('multiple') && $.isArray(ko.utils.unwrapObservable(valueAccessor()))) {
                     // in the case of a multiple select where the valueAccessor() is an observableArray, call the default Knockout selectedOptions binding
                     ko.bindingHandlers.selectedOptions.update(element, valueAccessor);
                 } else {
                     // call the default Knockout value binding
                     ko.bindingHandlers.value.update(element, valueAccessor);
                 }
             }

             $(element).selectpicker('refresh');
         }
     }
 };



   
};
