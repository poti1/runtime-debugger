#!/usr/bin/env perl

use lib qw( ../../lib );

use feature 'say';

sub Func {
    my $v = 111;

    use Runtime::Debugger;
    repl;
}

sub Func2 {
   &Func; 
}

Func2();

say "END";

1;
