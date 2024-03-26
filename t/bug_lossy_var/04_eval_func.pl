#!/usr/bin/env perl

use lib qw( ../../lib );

use feature 'say';

eval q(
    sub Func {
        my $v = 111;
    
        use Runtime::Debugger;
        repl;

        say "END inner";    
    }
    
    Func();
);

say "END";

1;
