#!/usr/bin/env perl

# Use case which causes Runtime::Debugger
# to "lose" track of variables.
#
# print $v.
# First time is ok.
# Next time is not:
# Variable "$v" is not available at (eval 13) line 1.

=pod

Statement
Evaled statement

Function.
Evaled function.

Coderef.
Evaled coderef.

Slurp, Statement
Slurp, Evaled statement

Slurp, Function.
Slurp, Evaled function.

Slurp, Coderef.
Slurp, Evaled coderef.


=cut

use feature 'say';

sub Func {
    my ( $code ) = @_;
    $code->();
}

Func(
    sub {
        my $v = 222;
        say "In coderef";

        # This causes lossy variable issues.
        use Runtime::Debugger;
     #  eval run;

        # Whereas, this one uses a source filter and works.
        # use Runtime::Debugger;
    }
);

say "Loaded pl";

22;
