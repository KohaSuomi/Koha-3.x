$(document).ready(function(){
	
	var pagenumber = $(".pagenumber").html();
	var maxpagenumber = $(".maxpage").val();
	var maxresults = $(".maxresults").val(); // Current results per page
	var showall = $(".show").val();
	
	if(parseInt(pagenumber) > parseInt(maxpagenumber) && parseInt(maxpagenumber) > 0){
		window.location = "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + maxpagenumber + "&results=" + maxresults + "&showall=" + showall;
	}
	
	if(parseInt(pagenumber) > 1){
		$(".pageprev").attr("href", "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + (parseInt(pagenumber)-1) + "&results=" + maxresults + "&showall=" + showall);
	}//if
	else{
		$(".pageprev").attr("href", "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + pagenumber + "&results=" + maxresults + "&showall=" + showall);
	}//else
	
	if(parseInt(pagenumber) == parseInt(maxpagenumber)){
		$(".pagenext").attr("href", "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + pagenumber + "&results=" + maxresults + "&showall=" + showall);
	}//if
	else{
		$(".pagenext").attr("href", "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + (parseInt(pagenumber)+1) + "&results=" + maxresults + "&showall=" + showall);
	}//else
	
	if(parseInt(showall) == 1){
		$(".showall").prop("checked", true);
	}//if
	else{
		$(".showall").prop("checked", false);
	}//else
	
	$(".showall").change(function(){
		
		if($(this).is(":checked")){
			showall = 1;
		}//if
		else{
			showall = 0;
		}//else
		
		window.location.href = "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + pagenumber + "&results=" + maxresults + "&showall=" + showall;
		
	});

	$(".selectall").change(function(){
		
		if($(this).is(":checked")){
			$("tbody :checkbox").prop("checked", true).trigger("change");
			$(".selectall").prop("checked", true);
		}//if
		else{
			$("tbody :checkbox").prop("checked", false).trigger("change");
			$(".selectall").prop("checked", false);
		}//else
		
	});
	
	$(".gotopage").click(function(e){
		
		e.preventDefault();
		
		var gotopagenumber = parseInt($(this).parent(".pagecontrol").find(".jumptopage").val());
		
		if(gotopagenumber == "" || gotopagenumber < 1){
			window.location.href = "/cgi-bin/koha/tools/sendOverdueBills.pl?page=1&results=" + maxresults + "&showall=" + showall;
		}//if
		else if(gotopagenumber > parseInt(maxpagenumber)){
			window.location.href = "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + maxpagenumber + "&results=" + maxresults + "&showall=" + showall;
		}//else if
		else if(gotopagenumber >= 1 && gotopagenumber <= parseInt(maxpagenumber)){
			window.location.href = "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + gotopagenumber + "&results=" + maxresults + "&showall=" + showall;
		}//else if
		
	});
	
	$(".pageresults").val(maxresults);
	
	$(".pageresults").change(function(){
		
		var resultset = $(this).val();
		
		window.location.href = "/cgi-bin/koha/tools/sendOverdueBills.pl?page=" + pagenumber + "&results=" + resultset + "&showall=" + showall;
		
	});

	$("tbody :checkbox").change(function(){
		
		var rissueid = $(this).parent().parent().attr("data-issueid"); // Issue id
		var rborrowernumber = $(this).parent().parent().attr("data-borrowernumber"); // Borrowernumber
		var ritemnum = $(this).parent().parent().attr("data-itemnum"); // itemnumber
		var rchild = $(this).parent().parent().attr("data-child"); // itemnumber
		var row = $(this).parent().parent().attr("data-rownumber"); // Rownumber
		
		if($(this).is(":checked")){
			
			var rduedate = $(this).parent().siblings("td:first").html(); // Due date
			if (rchild == 'CHILD') {
				var rpatron = $(this).parent().siblings("td:nth-child(3)").children("a:first").html().split(" ");
			} else {
				var rpatron = $(this).parent().siblings("td:nth-child(2)").children("a:first").html().split(" "); //rpatron[0] = surname, rpatron[1] = firstname
			}
			var rbd = $(this).parent().siblings("td:nth-child(4)").html(); // Date of birth
			var raddress = $(this).parent().siblings("td:nth-child(5)").html(); // Address
			var rzipcode = $(this).parent().siblings("td:nth-child(6)").html(); // Zipcode
			var rcity = $(this).parent().siblings("td:nth-child(7)").html(); // City
			var rtitle = $(this).parent().siblings("td:nth-child(8)").children("a:first").html() + 
						$(this).parent().siblings("td:nth-child(8)").children("span:first").html(); // Title and author
			var rprice = $(this).parent().siblings("td:nth-child(10)").children("input:first").val(); // Price
			var rfine = $(this).parent().siblings("td:nth-child(10)").children("input:eq(1)").val(); // Fine
			var rbillsent = $(this).parent().siblings("td:nth-child(11)").html(); // Last bill sent	
			
			if(rprice == "" || rprice < 0.00){
				rprice = $(this).parent().siblings("td:nth-child(10)").children("input:first").prop("placeholder");
			}//if
			else if(rprice >= 0.00){
				rprice = $(this).parent().siblings("td:nth-child(10)").children("input:first").val();
			}//else if
			else{
				rprice = 0.00;
			}//else
			if (rprice == 0.00) {
				alert("Aineistolla ei ole korvaushintaa, ole hyvä ja lisää se.");
			}
			if($("#borrower_" + rborrowernumber).length){ // Add data to #sendform as hidden inputs
				
				var brwrelement = $("#borrower_" + rborrowernumber);
				
				brwrelement.append($("<div>").attr("id", "borrowerrow_" + row));
				
				var brwrrow = $("#borrowerrow_" + row);
				
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "issue_id_" + row).val(rissueid));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "borrowernumber_" + row).val(rborrowernumber));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "itemnum_" + row).val(ritemnum));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "duedate_" + row).val(rduedate));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "surname_" + row).val(rpatron[0]));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "firstname_" + row).val(rpatron[1]));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "dateofbirth_" + row).val(rbd));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "address_" + row).val(raddress));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "zipcode_" + row).val(rzipcode));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "city_" + row).val(rcity));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "title_" + row).val(rtitle));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "replacementprice_" + row).val(rprice));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "fine_" + row).val(rfine));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "billingdate_" + row).val(rbillsent));
				
			}//if
			else{
				
				$("#sendform").prepend($("<div>").attr("id", "borrower_" + rborrowernumber));

				var brwrelement = $("#borrower_" + rborrowernumber);
				
				brwrelement.append($("<div>").attr("id", "borrowerrow_" + row));
				
				var brwrrow = $("#borrowerrow_" + row);
				
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "issue_id_" + row).val(rissueid));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "borrowernumber_" + row).val(rborrowernumber));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "itemnum_" + row).val(ritemnum));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "duedate_" + row).val(rduedate));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "surname_" + row).val(rpatron[0]));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "firstname_" + row).val(rpatron[1]));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "dateofbirth_" + row).val(rbd));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "address_" + row).val(raddress));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "zipcode_" + row).val(rzipcode));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "city_" + row).val(rcity));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "title_" + row).val(rtitle));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "replacementprice_" + row).val(rprice));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "fine_" + row).val(rfine));
				brwrrow.append($("<input>").prop("type", "hidden").attr("name", "billingdate_" + row).val(rbillsent));
				
			}//else
		}//if
		else{
			
			$("#borrowerrow_" + row).remove(); // Remove hidden inputs when checkbox gets unchecked
			
		}//else
	});
	
	$(".priceinput").change(function(){
		
		var checkbox = $(this).parent().siblings("td:nth-child(11)").children("input:first").is(":checked");
		var price = $(this).val();
		var priceholder = $(this).prop("placeholder");
		var row = $(this).parent().parent().attr("data-rownumber"); // Rownumber
		
		if(checkbox){

			if(price == "" || price < 0.00){
				$("input[name=replacementprice_" + row + "]").val(priceholder);
			}//if
			else if(price >= 0.00){
				$("input[name=replacementprice_" + row + "]").val(price);
			}//else if
			else{
				$("input[name=replacementprice_" + row + "]").val(0.00);
			}//else
			
		}//if
		
	});
	
});
