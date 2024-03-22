#!/usr/bin/env perl

use lib qw( ../../lib );

BEGIN {
    $ENV{RUNTIME_DEBUGGER_DEBUG} = 1;
}

use feature 'say';

=pod

both work!

=cut

my $v = 111;

use Runtime::Debugger;

# use Runtime::Debugger -nofilter;
# eval run;

say "END";

1;
