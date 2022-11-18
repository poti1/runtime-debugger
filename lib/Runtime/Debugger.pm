package Runtime::Debugger;

use 5.012;
use strict;
use warnings;

=head1 NAME

Runtime::Debugger - Debug perl wihle its running.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Run a REPL debugger in the current scope.

    use Runtime::Debugger;
    Runtime::Debugger->run;


=head1 SUBROUTINES/METHODS

=head2 run

Runs the REPL.

=cut

sub run {
    while(1){
        printf "perl> ";
        my $Input = <STDIN>;
        chomp $Input;

        # compgen -W '\$Selenium \$Editor exit quit q' '$E'
        # Term::ReadKey. Tab completion.
        # Up and down arrows to scroll through history.

        last if $Input =~ / ^ (?: exit | quit | q ) $ /x;

        eval "$Input";
    }
}

=head1 AUTHOR

Tim Potapov, C<< <tim.potapov[AT]gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to L<https://github.com/poti1/runtime-debugger/issues>.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Runtime::Debugger


You can also look for information at:

L<https://metacpan.org/Runtime::Debugger>
L<https://github.com/poti1/runtime-debugger>


=head1 ACKNOWLEDGEMENTS

TBD

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2022 by Tim Potapov.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1; # End of Runtime::Debugger
