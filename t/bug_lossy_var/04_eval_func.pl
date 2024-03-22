#!/usr/bin/env perl

use lib qw( ../../lib );

BEGIN {
    $ENV{RUNTIME_DEBUGGER_DEBUG} = 1;
}

use feature 'say';

=pod

Must use eval run.

=cut

eval q(
    sub Func {
        my $v = 111;
    
        use Runtime::Debugger;
    
        # use Runtime::Debugger -nofilter;
        # eval run;
    }
    
    Func();
);

say "END";

1;
