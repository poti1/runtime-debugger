#!/usr/bin/env perl

use lib qw( ../../lib );

use feature 'say';

sub {
    my $v = 777;

    use Runtime::Debugger;
    repl;

    say "END inner";
}->();

say "END";

1;

