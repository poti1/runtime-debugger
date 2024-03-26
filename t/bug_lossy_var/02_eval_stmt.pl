#!/usr/bin/env perl

use lib qw( ../../lib );

use feature 'say';

eval q(
    my $v = 111;
    
    use Runtime::Debugger;
    repl;

    say "END inner";
);

say "END";

1;
