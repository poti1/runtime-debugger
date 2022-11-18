package Runtime::Debugger;

use 5.012;
use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor qw( colored );
use Term::ReadLine;
use feature 'say';
use parent 'Exporter';

our $TERM;
our @EXPORT = qw(
  run
  p
);

=head1 NAME

Runtime::Debugger - Debug perl wihle its running.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Run a REPL debugger in the current scope.

    use Runtime::Debugger;
    eval run;


=head1 SUBROUTINES/METHODS

=head2 run

Runs the REPL.

=cut

sub run {
    "eval Runtime::Debugger->_step while 1";
}


sub _step {
    $Runtime::Debugger::TERM //= Term::ReadLine->new( "Runtime::Debugger" );

    my $input = $TERM->readline( "perl>" );

    exit if $input =~ / ^ (?: exit | quit | q ) $ /x;

    # compgen -W '\$Selenium \$Editor exit quit q' '$E'
    # Term::ReadKey. Tab completion.
    # Up and down arrows to scroll through history.

    $input;
}

=head2 p

Data::Dumper::Dump anything.

 p 123
 p [1 ,2, 3]

=cut

sub p {
    my $d = Data::Dumper
      ->new( \@_ )
      ->Sortkeys( 1 )
      ->Terse( 1 )
      ->Indent( 1 )
      ->Maxdepth( 1 );

    return $d->Dump if wantarray;
    print $d->Dump;
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

1;    # End of Runtime::Debugger
