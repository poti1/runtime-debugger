#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Runtime::Debugger' ) || print "Bail out!\n";
}

diag( "Testing Runtime::Debugger $Runtime::Debugger::VERSION, Perl $], $^X" );
