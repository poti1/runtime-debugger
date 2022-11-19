package Runtime::Debugger;

use 5.012;
use strict;
use warnings;
use Data::Dumper;
use Term::ReadLine;
use Term::ANSIColor qw( colored );
use PadWalker       qw( peek_my  );
use feature 'say';
use parent 'Exporter';
use subs qw( p );

our $TERM;
our @EXPORT = qw(
  run
  p
);

=head1 NAME

Runtime::Debugger - Debug perl wihle its running.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


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
    local $SIG{INT}  = \&Runtime::Debugger::_interrupt;
    local $SIG{TERM} = \&Runtime::Debugger::_interrupt;
    local $SIG{HUP}  = \&Runtime::Debugger::_interrupt;

    if ( not $Runtime::Debugger::TERM ) {
        $TERM = Term::ReadLine->new( "Runtime::Debugger" );
        $TERM->ornaments( 0 );
        $TERM->add_defun('custom-action', sub{
            my($count, $key) = @_; 
            $TERM->complete_internal( ord '*' );
            return 0;       
        });
        $TERM->bind_key(ord "\cy", 'custom-action');

        my $lexicals  = peek_my(1);
        my @lex_names = sort keys %$lexicals;
        my $attribs = $TERM->Attribs;

      # $attribs->{completion_entry_function} = $attribs->{list_completion_function};
        $attribs->{completion_word} = \@lex_names;
        $attribs->{completion_function } = sub {
            my ($text, $line, $start ) = @_;
            say "\nFUNC text=[$text] line=[$line], start=[$start]";
            p $TERM->completion_matches($text, $attribs->{'list_completion_function'} );
        };
      # $attribs->{attempted_completion_function } = sub {
      #     my ($text, $line, $start, $end) = @_;
      #     say "\nATTEMP: text=[$text] line=[$line], start=[$start], end=[$end]";
      #     $TERM->completion_matches($text, $attribs->{'list_completion_function'} );
      # };


        # Preload history.
        # $TERM->AddHistory( 'say $v', 'p $v', );
    }

    my $input = $TERM->readline( "perl>" ) // '';

    Runtime::Debugger->_exit if $input eq 'q';

    # Tab completion.
    # compgen -W '\$Selenium \$Editor exit quit q' '$E'

    $input;
}

sub _interrupt {
    say "Type 'q' to quit";
}

sub _exit {
    die "Exit\n";
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
