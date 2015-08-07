$("#sendinvoiceBtn").click(function( event ) {
	event.preventDefault();

	var accountlines = [];

	$('input[type=checkbox]:checked').each(function () {
	    accountlines.push($(this).attr("id"));
	});

	$.ajax({
	   type: "POST",
	   data: {accountlines:accountlines},
	   url: "/cgi-bin/koha/members/sendinvoice.pl",
	   success: function(msg){
	   		if(msg==1){
	   			alert("Lähetys onnistui!");
	   		} else {
	   			alert("Et ole valinnut lähetettäviä maksuja.");
	   		}
	     	
	   }
	});

});

