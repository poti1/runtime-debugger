#!/usr/bin/env perl

use lib qw( ../../lib );

use feature 'say';

my $v = 111;

use Runtime::Debugger;

repl;

say "END";

1;
