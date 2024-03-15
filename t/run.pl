#!/usr/bin/env perl

# Use case which causes Runtime::Debugger
# to "lose" track of variables.
#
# print $v.
# First time is ok.
# Next time is not:
# Variable "$v" is not available at (eval 13) line 1.

sub Func {
    my ( $code ) = @_;
    $code->();
}

Func(
    sub {
        my $v2 = 222;

        # This causes issues.
        # use Runtime::Debugger -nofilter;
        # eval run;

        # Whereas, this one uses a source filter and works.
        use Runtime::Debugger;
    }
);

