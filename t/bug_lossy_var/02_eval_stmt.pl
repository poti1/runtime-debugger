#!/usr/bin/env perl

use lib qw( ../../lib );

BEGIN {
    $ENV{RUNTIME_DEBUGGER_DEBUG} = 1;
}

use feature 'say';

=pod

Manually need to trigger eval run.

FILTER is not triggered!

Eval run works and is not lossy.

=cut

eval q(
    my $v = 111;
    
    # Does not work.
    # use Runtime::Debugger;
   
    # Same, does not work.
    # require Runtime::Debugger;
    # Runtime::Debugger->import;

    # Works.
    use Runtime::Debugger -nofilter;
    eval run;

    # Also works since FILTER is NOT triggered.
    # use Runtime::Debugger;
    # eval run;

    say "END inner";
);

say "END";

1;
