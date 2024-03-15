#!/usr/bin/env perl

# Use case which causes Runtime::Debugger
# to "lose" track of variables.
#
# print $v.
# First time is ok.
# Next time is not:
# Variable "$v" is not available at (eval 13) line 1.

eval q(
    sub Func {
        my ($code) = @_;
        eval { $code->() }
    }

    Func( sub{
        my $v = 111;
        use Runtime::Debugger;
        eval run;
    });
);

