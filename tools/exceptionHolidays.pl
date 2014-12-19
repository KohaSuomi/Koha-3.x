#!/usr/bin/perl

use strict;
use warnings;

use CGI;

use C4::Auth;
use C4::Output;
use DateTime;

use C4::Calendar;

my $input = new CGI;
my $dbh = C4::Context->dbh();

my $branchcode = $input->param('showBranchName');
my $weekday = $input->param('showWeekday');
my $day = $input->param('showDay');
my $month = $input->param('showMonth');
my $year = $input->param('showYear');
my $day1;
my $month1;
my $year1;
my $title = $input->param('showTitle');
my $description = $input->param('showDescription');
my $holidaytype = $input->param('showHolidayType');
my $datecancelrange = $input->param('datecancelrange');
my $calendardate = sprintf("%04d-%02d-%02d", $year, $month, $day);
my $isodate = C4::Dates->new($calendardate, 'iso');
$calendardate = $isodate->output('syspref');

my $calendar = C4::Calendar->new(branchcode => $branchcode);

$title || ($title = '');
if ($description) {
    $description =~ s/\r/\\r/g;
    $description =~ s/\n/\\n/g;
} else {
    $description = '';
}   


my $datecancelrange = C4::Dates->new($datecancelrange)->output('iso');
my @dateend = split(/[\/-]/, $datecancelrange);
$year1 = $dateend[0];
$month1 = $dateend[1];
$day1 = $dateend[2];

# We make an array with holiday's days
my @holiday_list;
if ($year1 && $month1 && $day1){
            my $first_dt = DateTime->new(year => $year, month  => $month,  day => $day);
            my $end_dt   = DateTime->new(year => $year1, month  => $month1,  day => $day1);

            for (my $dt = $first_dt->clone();
                $dt <= $end_dt;
                $dt->add(days => 1) )
                {
                push @holiday_list, $dt->clone();
                }
}
if ($input->param('showOperation') eq 'exception') {
	$calendar->insert_exception_holiday(day => $day,
										month => $month,
									    year => $year,
						                title => $title,
						                description => $description);
} elsif ($input->param('showOperation') eq 'exceptionrange' ) {
        if (@holiday_list){
            foreach my $date (@holiday_list){
                $calendar->insert_exception_holiday(
                    day         => $date->{local_c}->{day},
                    month       => $date->{local_c}->{month},
                    year       => $date->{local_c}->{year},
                    title       => $title,
                    description => $description
                    );
            }
        }
} elsif ($input->param('showOperation') eq 'edit') {
    if($holidaytype eq 'weekday') {
      $calendar->ModWeekdayholiday(weekday => $weekday,
                                   title => $title,
                                   description => $description);
    } elsif ($holidaytype eq 'daymonth') {
      $calendar->ModDaymonthholiday(day => $day,
                                    month => $month,
                                    title => $title,
                                    description => $description);
    } elsif ($holidaytype eq 'ymd') {
      $calendar->ModSingleholiday(day => $day,
                                  month => $month,
                                  year => $year,
                                  title => $title,
                                  description => $description);
    } elsif ($holidaytype eq 'exception') {
      $calendar->ModExceptionholiday(day => $day,
                                  month => $month,
                                  year => $year,
                                  title => $title,
                                  description => $description);
    }
} elsif ($input->param('showOperation') eq 'delete') {
	$calendar->delete_holiday(weekday => $weekday,
	                          day => $day,
  	                          month => $month,
				              year => $year);
}elsif ($input->param('showOperation') eq 'deleterange') {
    if (@holiday_list){
        foreach my $date (@holiday_list){
            $calendar->delete_holiday_range(weekday => $weekday,
                                            day => $date->{local_c}->{day},
                                            month => $date->{local_c}->{month},
                                            year => $date->{local_c}->{year});
            }
    }
}elsif ($input->param('showOperation') eq 'deleterangerepeat') {
    if (@holiday_list){
        foreach my $date (@holiday_list){
           $calendar->delete_holiday_range_repeatable(weekday => $weekday,
                                         day => $date->{local_c}->{day},
                                         month => $date->{local_c}->{month});
        }
    }
}elsif ($input->param('showOperation') eq 'deleterangerepeatexcept') {
    if (@holiday_list){
        foreach my $date (@holiday_list){
           $calendar->delete_exception_holiday_range(weekday => $weekday,
                                         day => $date->{local_c}->{day},
                                         month => $date->{local_c}->{month},
                                         year => $date->{local_c}->{year});
        }
    }
}
print $input->redirect("/cgi-bin/koha/tools/holidays.pl?branch=$branchcode&calendardate=$calendardate");
