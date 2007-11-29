use strict;

use Test::More tests => 4;
use Data::ICal::DateTime;
use DateTime;
use DateTime::Set;
use DateTime::TimeZone;

my $cal;
ok($cal = Data::ICal->new( filename => 't/ics/recur.ics'), "parse recur ics")
 or diag( $cal->error_message );

my $date1 = DateTime->new( year => 2005, month => 6, day => 20 );
my $date2 = DateTime->new( year => 2005, month => 6, day => 26, hour => 11, minute => 59 );
my $set   = DateTime::Span->from_datetimes( start => $date1, end => $date2 );

my @events = $cal->events;
is (@events, 1, "1 total event");
@events    = $cal->events($set);
is (@events, 7, "7 recurring events");

@events    = $cal->events($set,'minute');
is (@events, 7*60, "420 split recurring events");

