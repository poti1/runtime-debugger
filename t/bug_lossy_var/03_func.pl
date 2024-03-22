#!/usr/bin/env perl

use lib qw( ../../lib );

BEGIN {
    $ENV{RUNTIME_DEBUGGER_DEBUG} = 1;
}

use feature 'say';

=pod

both work!

Problem is not multi sub calls.

No issue using &Func, &Func()

Instead, has to do with coderefs.

=cut

use O qw( Deparse );

sub Func {
    my $v = 111;

    # use Runtime::Debugger;

    use Runtime::Debugger -nofilter;
    eval run;
}

sub Func2 {
   &Func; 
}

Func2();

say "END";

1;
