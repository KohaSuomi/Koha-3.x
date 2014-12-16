[%# This template must receive a parameter stl_name, containing the name of the subscription length type, either 'monthlength', 'numberlength' or 'weeklength'.Eg. "\[% INCLUDE showSubscriptionLengthType stl_name=subt.name %\]" %]
[% IF (stl_name) == 'numberlength' %]
<span>issues</span>
[% ELSIF (stl_name) == 'weeklength' %]
<span>weeks</span>
[% ELSIF (stl_name) == 'monthlength' %]
<span>months</span>
[% END %]