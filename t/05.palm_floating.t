use strict;


use Test::More tests => 5;


use Data::ICal::DateTime;
use Data::ICal::Entry::Event;
use DateTime;
use DateTime::Set;
use DateTime::TimeZone;

my $cal;
ok($cal = Data::ICal->new( filename => 't/ics/palm.ics'), "parse palm ics");

my $date1 = DateTime->new( year => 2005, month => 10, day => 3 );
my $date2 = $date1->clone->add( days => 1 )->subtract( nanoseconds => 1 );

my @events = $cal->events;
use Data::Dumper;
is(scalar(@events),1,"1 event");

my $ev = shift @events;
my $s  = $ev->start;
my $e  = $ev->end;
is("$s", "$date1", "Start is the same as date");
is("$e", "$date2", "End is the same as date");
is($ev->all_day, 1, "Event is all_day");
