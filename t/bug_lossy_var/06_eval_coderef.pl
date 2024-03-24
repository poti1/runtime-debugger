#!/usr/bin/env perl

use lib qw( ../../lib );

use feature 'say';

eval q(
    sub {
        my $v = 777;
    
        use Runtime::Debugger;
        repl;
    
        say "END inner";
    }->();
    
    say "END inner2";
);

say "END";

1;

