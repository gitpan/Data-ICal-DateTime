package Data::ICal::DateTime;

use strict;
use Clone;
use Data::ICal;
use DateTime::Set;
use DateTime::Format::ICal;

our $VERSION = '0.4';

# mmm, mixin goodness
sub import {
    my $class = shift;
    no strict 'refs';
    no warnings 'redefine';
    *Data::ICal::events = \&events;
    foreach my $sub (qw(start end duration period summary description 
                        all_day recurrence recurrence_id rdate exrule exdate uid 
                        _rule_set _date_set explode is_in _normalise)) 
    {
        *{"Data::ICal::Entry::Event::$sub"} = \&$sub;
    }
    push @Data::ICal::Entry::Event::ISA, 'Clone';
}



=head1 NAME

Data::ICal::DateTime - convenience methods for using Data::ICal with DateTime

=head1 SYNPOSIS

    # performs mixin voodoo
    use Data::ICal::DateTime; 
    my $cal = Data::ICal->new( filename => 'example.ics');


    my $date1 = DateTime->new( year => 2005, month => 7, day => 01 );
    my $date2 = DateTime->new( year => 2005, month => 7, day => 07 );
    my $span  = DateTime::Span->from_datetimes( start => $date1, end => $date2 );

    my @events = $cal->events();           # all VEVENTS
    my @week   = $cal->events($span);      # just in that week
    my @week   = $cal->events($span,'day');# explode long events into days 

    my $event = Data::ICal::Entry::Event->new();
    
    $event->start($start);                 # $start is a DateTime object
    $event->end($end);                     # so is $end

    $event->duration($duration);           # $duration is DateTime::Duration 
    $event->recurrence($recurrence);       # $reccurence is a DateTime list, 
                                           # a DateTime::Span list,  
                                           # a DateTime::Set, 
                                           # or a DateTime::SpanSet
 
    $event->start;                         # returns a DateTime object
    $event->end;                           # ditto
    $event->duration;                      # returns a DateTime::Duration
    $event->recurrence;                    # returns a DateTime::Set
    $event->period;                        # returns a DateTime::Span object
    $event->rdate;                         # returns a DateTime::Set
    $event->exrule;                        # returns a DateTime::Set
    $event->exdate;                        # returns a DateTime::Set
    $event->explode($span);                # returns an array of sub events
                                           # (if this is recurring);
    $event->explode($span,'week');         # if any events are longer than a 
                                           # week then split them up
    $event->is_in($span);                  # whether this event falls within a 
                                           # Set, Span, or SetSpan


    $cal->add($event);

methods


=head1 DESCRIPTION

=head1 METHODS

=cut

=head2 events [span] [period]

Provides a L<Data::ICal> object with a method to return all events.

If a L<DateTime::Set>, L<DateTime::Span> or L<DateTime::SpanSet> object
is passed then only the events that occur within that set will be
returned including expansion of all recurring events. All events will be
normalised to have a dtstart and dtend rather than any other method of
determining their start and stop time.

Additionally you can pass a period string which can be one of the 
following

    year month week day hour 
    minute second nanosecond

This will explode an event into as many sub events as needed e.g a 
period of 'day' will explode a 2-day event into 2 one day events with 
the second starting just after the first

=cut

sub events {
    my $self = shift;

    # NOTE: this won't normalise events   
    return grep  { $_->ical_entry_type eq 'VEVENT' } @{$self->entries} if (!@_);

    my %rid;
    ENTRY: for (@{$self->entries}) {
        next unless $_->ical_entry_type eq 'VEVENT';
        if ($_->recurrence_id){
            foreach my $exploded ($_->explode(@_)) {
                my $uid = $exploded->uid; $uid = rand().{}.time unless defined $uid;
                foreach my $e (@{$rid{$uid}}) {
                    next unless $e->start == $exploded->recurrence_id;
                    $e = $exploded;
                }
            }            
            next ENTRY;
        }
        my $uid = $_->uid; $uid = rand().{}.time unless defined $uid;
        push @{$rid{$uid}}, $_->explode(@_);
    }
    my @events;
    push @events, @$_ for values %rid; 
    return @events;
}


=head2 start [new]

Returns a L<DateTime> object representing the start time of this event.

May return undef.

If passed a L<DateTime> object will set that to be the new start time.

=cut 
    
sub start {
    my $self = shift;
    my $new  = shift; 

    if ($new) {
         delete $self->{properties}->{dtstart};
         $self->add_property(dtstart => DateTime::Format::ICal->format_datetime($new));
    }


    my $dtstart = $self->property('dtstart') || return undef;
    my $ret     = DateTime::Format::ICal->parse_datetime($dtstart->[0]->value);

    # $ret->set_time_zone($dtstart->[0]->parameters->{TZID}) if $dtstart->[0]->parameters->{TZID};

    return $ret;

}

=head2 end

Returns a L<DateTime> object representing the end time of this event.

May return undef.

If passed a L<DateTime> object will set that to be the new end time.

=cut 


sub end {
    my $self = shift;
    my $new  = shift;

    # iCal represents all-day events by using ;VALUE=DATE 
    # and setting DTEND=end_date + 1

    if ($new) {
         my $all_day = $self->all_day;
         delete $self->{properties}->{dtend};
         # $new->add( days => 1) if $all_day;              
         $self->add_property( dtend => DateTime::Format::ICal->format_datetime($new) );
         # $self->property('dtend')->[0]->parameters->{VALUE} = 'DATE' if $all_day;

    }


    my $dtend  = $self->property('dtend') || return undef;
    my $ret    = DateTime::Format::ICal->parse_datetime($dtend->[0]->value);

    # $ret->set_time_zone($dtend->[0]->parameters->{TZID}) if ($dtend->[0]->parameters->{TZID});
    # $ret->subtract( days => 1 ) if $dtend->[0]->parameters->{VALUE} && $dtend->[0]->parameters->{VALUE} eq 'DATE';

    return $ret;
}

=head2 all_day

Returns 1 if event is all day or 0 if not.

=cut

sub all_day {
    my $self = shift;
    my $new  = shift;

    my $dtend  = $self->property('dtend') || return 0;
    return $dtend->[0]->parameters->{VALUE} && $dtend->[0]->parameters->{VALUE} eq 'DATE';
}

=head2 duration

Returns a L<DateTime::Duration> object representing the duration of this
event.

May return undef.

If passed a L<DateTime::Duration> object will set that to be the new 
duration.


=cut 

sub duration {
    my $self = shift;
    my $new  = shift; 

    if ($new) {
         delete $self->{properties}->{duration};
         $self->add_property( duration => DateTime::Format::ICal->format_duration($new) );
    }

    my $duration = $self->property('duration') || return undef;
    return DateTime::Format::ICal->parse_duration($duration->[0]->value);
}


=head2 period 

Returns a L<DateTime::Span> object representing the period of this
event.

May return undef.

If passed a L<DateTime::Span> object will set that to be the new
period.

=cut

sub period {
    my $self = shift;
    my $new  = shift;

    if ($new) {
        delete $self->{properties}->{period};
        $self->add_property( period => DateTime::Format::ICal->format_period($new) );
    }

    my $period  = $self->property('period') || return undef;
    my $ret     = DateTime::Format::ICal->parse_period($period->[0]->value);

    # $ret->set_time_zone($period->[0]->parameters->{TZID}) if ($period->[0]->parameters->{TZID});
    return $ret;
}


=head2 recurrence

Returns a L<DateTime::Set> object representing the union of all the 
C<RRULE>s in this object.

May return undef.

If passed one or more L<DateTime> lists, L<DateTime::Span> lists, L<DateTime::Set>s, 
or L<DateTime::SpanSet>s then set the recurrence rules to be those.

=cut 

sub recurrence {
    my $self = shift;
    

    return $self->_rule_set('rrule');
}

=head2 rdate

Returns a L<DateTime::Set> object representing the set of all C<RDATE>s in the object.

May return undef.

=cut

sub rdate {
    my $self = shift;

    return $self->_date_set('rdate');
}


=head2 exrule

Returns a L<DateTime::Set> object representing the union of all the
C<EXRULE>s in this object.

May return undef.

If passed one or more L<DateTime> lists, L<DateTime::Span> lists, L<DateTime::Set>s,
or L<DateTime::SpanSet>s then set the recurrence rules to be those.

=cut


sub exrule {
    my $self = shift;

    return $self->_rule_set('exrule');

}

=head2 exdate

Returns a L<DateTime::Set> object representing the set of all C<RDATE>s in the object.

May return undef.

=cut

sub exdate {
    my $self = shift;

    return $self->_date_set('exdate');
}



sub _date_set {
    my $self = shift;
    my $name = shift;


    $self->property($name) || return undef;
    my @dates;
    for (@{ $self->property($name) }) {
        my $date     = DateTime::Format::ICal->parse_datetime($_->value);
        # $date->set_time_zone($_->parameters->{TZID}) if $_->parameters->{TZID};
        push @dates, $date;
    }
    return DateTime::Set->from_datetimes( dates => \@dates );

}

 
sub _rule_set {
    my $self  = shift;
    my $name  = shift;

    if (@_) {
        delete $self->{properties}->{$name};
        $self->add_properties( $name => DateTime::Format::ICal->format_recurrence(@_) );
    }


    my @recurrence;
    my $start = $self->start || return undef;
    my $tz    = $start->time_zone;

    $start = $start->clone;
    $start->set_time_zone("floating");

    my $set = DateTime::Set->empty_set;
    $self->property($name) || return undef;
    for (@{ $self->property($name) }) {
        my $recur   = DateTime::Format::ICal->parse_recurrence(recurrence => $_->value, dtstart => $start);
        # $recur->set_time_zone($_->parameters->{TZID}) if $_->parameters->{TZID};
        $set = $set->union($recur);
    }
    # $set->set_time_zone($tz);
    return $set;


}

=head2 recurrence_id

Returns a L<DateTime> object representing the recurrence-id of this event.

May return undef.

If passed a L<DateTime> object will set that to be the new recurrence-id.

=cut

sub recurrence_id {
    my $self = shift;
    my $new  = shift; 

    if ($new) {
         delete $self->{properties}->{'recurrence-id'};
         $self->add_property('recurrence-id' => DateTime::Format::ICal->format_datetime($new));
    }


    my $rid  = $self->property('recurrence-id') || return undef;
    my $ret  = DateTime::Format::ICal->parse_datetime($rid->[0]->value);

    # $ret->set_time_zone($rid->[0]->parameters->{TZID}) if $rid->[0]->parameters->{TZID};

    return $ret;

}

=head2 uid

Returns the uid of this event.

If passed a new value then sets that to be the new uid value. 

=cut

sub uid {
    my $self = shift;
    my $uid  = shift;

    if ($uid) {
        delete $self->{properties}->{uid};
        $self->add_property( uid => $uid );
    }

    $uid = $self->property('uid') || return undef;
    return $uid->[0]->value;
}

=head2 summary

Returns a string representing the summary of this event.

This string may contain embedded new lines and other escaped characters.

It may be useful to do

    my $summ = $event->summary || '';
    evel "\$summ = \"$summ\";";


May return undef.

=cut 

sub summary {
    my $self = shift;
    my $summ = shift;

    if ($summ) {
        delete $self->{properties}->{summary};
        $self->add_property( summary => $summ );
    }

    $summ = $self->property('summary') || return undef;
    return $summ->[0]->value;
}

=head2 description

Returns a string representing the summary of this event.

This string may contain embedded new lines and other escaped characters.

It may be useful to do

    my $desc = $event->description || '';
    evel "\$desc = \"$desc\";";


May return undef.

=cut 


sub description {
    my $self = shift;
    my $desc = shift;

    if ($desc) {
        delete $self->{properties}->{description};
        $self->add_property( description => $desc );
    }
 
    $desc = $self->property('description') || return undef;
    return $desc->[0]->value;
}



=head2 explode <span> [period]

Takes L<DateTime::Set>, L<DateTime::Span> or L<DateTime::SpanSet> and 
returns an array of events.

If this is not a recurring event, and it falls with the span, then it
will return one event with the dtstart and dtend properties set and no
other time information.

If this is a recurring event then it will return all times that this 
recurs within the span. All returned events will have the dtstart and 
dtend properties set and no other time information.

If C<period> is optionally passed then events longer than C<period> will 
be exploded into multiple events.

C<period> can be any of the following

    year month week day hour
    minute second nanosecond

=cut 

# this is quite heavily based on 'wgo' in the bin/ directory of Text::vFile::asData
sub explode {
    my $self   = shift;
    my $span   = shift;
    my $period = shift;
    my %e      = $self->_normalise;


    my @events;

    if (! $e{recur} && $e{span}->intersects($span) ) {
        my $event = $self->clone();
        delete $event->{properties}->{$_} for qw(rrule exrule rdate exdate duration period);
        $event->start($e{start});
        $event->end($e{end});
        push @events, $event;
    }


    if($e{recur} && $e{recur}->intersects($span)) {
        my $int_set = $e{recur}->intersection($span);

      
        # Change the event's recurrence details so that only the events
        # inside the time span we're interested in are listed.
        $e{recur} = $int_set;
        my $it    = $e{recur}->iterator;
        while(my $dt = $it->next()) {
            next if $e{exrule} && $e{exrule}->contains($dt);
            next if $e{exdate} && $e{exdate}->contains($dt);            
            my $event = $self->clone();
            delete $event->{properties}->{$_} for qw(rrule exrule rdate exdate duration period);

            $event->start($dt);
            my $end = $dt + $e{duration};
            $event->end($end);
            push @events, $event;
        }
    }
    return @events if !defined $period;


    my @new;
    foreach my $event (@events) {
        my $span = DateTime::Span->from_datetimes( start => $event->start, end => $event->end );
        my $dur  = DateTime::Duration->new("${period}s" => 1)->subtract( "nanoseconds" => 1 );
        my $r    = DateTime::Set->from_recurrence(
                                       recurrence => sub {
                                         $_[0]->truncate(to => $period )->add("${period}s" => 1);
                                       },
                                       span => $span);
        $r       = $r->union(DateTime::Set->from_datetimes(dates => [$event->start]));

        my $i    = $r->iterator;
        while (my $dt = $i->next) {
            my $e = $event->clone;
            $e->start($dt);
            my $end = $dt->add( days => 1);
            $end->set ( hour => 0, minute => 0, second => 0, nanosecond => 0);
            $end = $end->subtract( nanoseconds => 1 );
            
            $e->end($end);
            push @new, $e;
        }
        # If, say we have a one week and 1 day event and period is  
        # 'week' then need to truncate to one 1 week event and one
        # day event. 
        # $end = $e{end} if ( defined $period && $e{end} < $end);
        $new[-1]->end($event->end);
    }
    return @new;
}

=head2 is_in <span>

Takes L<DateTime::Set>, L<DateTime::Span> or L<DateTime::SpanSet> and
returns whether this event can fall within that time frame.

=cut

sub is_in {
    my $self = shift;
    my $span = shift;

    my %e = $self->_normalise;


    return ( ( !$e{recur} && $e{span}->intersects($span)    )    ||
             (  $e{recur} && $e{recur}->intersection($span) ) );

}

# return normalised informaiton about this event
sub _normalise {
    my $self = shift;

    my %e = ();                         

    $e{period}   = $self->period;
    $e{start}    = $self->start;
    $e{end}      = $self->end;
    $e{duration} = $self->duration;
    $e{recur}    = $self->recurrence;
    $e{exrule}   = $self->exrule;
    $e{rdate}    = $self->rdate;
    $e{exdate}   = $self->exdate;

    
    if (defined $e{period}) {
        if (defined $e{start} || defined $e{end}) {
            die "Found a period *and* a start or end:\n".$self->as_string;
        }
        
        $e{start} = $e{period}->start;
        $e{end}   = $e{period}->end;

    }



    if (!defined $e{start}) {
        die "Couldn't find start\n".$self->as_string;
    }

    if (defined $e{end} && defined $e{duration}) {
        die "Found both end *and* duration:\n".$self->as_string;
    }
    if (!defined $e{end} && !defined $e{duration}) {
        die "Couldn't find end *or* duration:\n".$self->as_string;
    }

    if (defined $e{duration}) {
        $e{end} = $e{start} + $e{duration};
    }

    if ($e{rdate}) {
        $e{recur} = (defined $e{recur}) ? $e{recur}->union($e{rdate}) : $e{rdate};
    }


    $e{span}     = DateTime::Span->from_datetimes( start => $e{start}, end => $e{end} );

    $e{duration} = $e{span}->duration;

    return %e;
}


=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYING

Copyright, 2005 Simon Wistow

Distributed under the same terms as Perl itself.

=head1 BUGS

Potential timezone problems?

Exploding to a second or nanosecond might not work properly.

Some shennanigans with all day events

=head1 SEE ALSO

L<DateTime>, L<DateTime::Set>, L<Data::ICal>, L<Text::vFile::asData>, L<iCal::Parser> 

=cut

1;