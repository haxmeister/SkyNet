package SkyNet::Pilot;

use strict;
use warnings;
use SkyNet::Dispatcher;

my $dispatch = SkyNet::Dispatcher->new();

my %Pilots = ();


sub new {
    my $package = shift;
    my $self    = bless {
           mux  => shift,
           fh   => shift,
               }=> $package;

    # Register the new Pilot object as the callback specifically for
    # this file handle.

    $self->{mux}->set_callback_object($self, $self->{fh});
    #print $self->{fh}
     #   "Greetings, Professor.  Would you like to play a game?\n";

    # Register this Pilot object in the main list of Pilots
    $Pilots{$self} = $self;
    $mux->set_timeout($self->{fh}, 1);
}

sub Pilots { return values %Pilots; }

sub mux_input {
    my $self = shift;
    shift; shift;         # These two args are boring
    my $input = shift;    # Scalar reference to the input

    # Process each line in the input, leaving partial lines
    # in the input buffer
    while ($$input =~ s/^(.*?)\n//) {
        $self->process_command($1);
    }
}

sub mux_close {
   my $self = shift;

   # Pilot disconnected;
   # [Notify other Pilots or something...]
   delete $Pilots{$self};
}

# This gets called every second to update Pilot info, etc...
sub mux_timeout {
    my $self = shift;
    my $mux  = shift;

    $self->heartbeat;
    $mux->set_timeout($self->{fh}, 1);
}

1;
