package Runtime::Debugger;

=head1 LOGO

 ____              _   _
|  _ \ _   _ _ __ | |_(_)_ __ ___   ___
| |_) | | | | '_ \| __| | '_ ` _ \ / _ \
|  _ <| |_| | | | | |_| | | | | | |  __/
|_| \_\\__,_|_| |_|\__|_|_| |_| |_|\___|

 ____       _
|  _ \  ___| |__  _   _  __ _  __ _  ___ _ __
| | | |/ _ \ '_ \| | | |/ _` |/ _` |/ _ \ '__|
| |_| |  __/ |_) | |_| | (_| | (_| |  __/ |
|____/ \___|_.__/ \__,_|\__, |\__, |\___|_|
                        |___/ |___/

=cut

use 5.012;
use strict;
use warnings;
use Data::Dumper;
use Term::ReadLine;
use Term::ANSIColor qw( colored );
use PadWalker       qw( peek_my  );
use feature         qw( say );
use parent          qw( Exporter );
use subs            qw( p uniq );

our @EXPORT = qw(
  run
  p
  uniq
);

=head1 NAME

Runtime::Debugger - Debug perl while its running.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

One can usually just do this:

 # Insert this where you want to pause:
 DB::single = 1;

 # Then run the perl debugger to navigate there quickly:
 PERLDBOPT='Nonstop' perl -d my_script

If that works for then great and dont' bother using this module!

Unfortunately for me, it was not working due to the scenario
in which a script evals another perl test file and I would have
liked to pause inside the test and see whats going on without
having to keep rerunning the whole test over and over.

This module basically drops in a read,evaludate,print loop (REPL)
whereever you need like so:

    use Runtime::Debugger;
    eval run;                # Not sure how to avoid using eval here while
                             # also being able to keep the lexical scope.
                             # Any ideas ? :)

Try with this command line:

    perl -MRuntime::Debugger -E 'my $str1 = "str-1"; my $str2 = "str-2"; my @arr1 = "arr-1"; my @arr2 = "arr-2"; my %hash1 = qw(hash 1); my %hash2 = qw(hash 2);  eval run; say $@'

Press tab to autocomplete any lexical variables in scope.

Saves history locally.

=head1 SUBROUTINES/METHODS

=head2 run

Runs the REPL.

Sets C<$@> to the exit reason like 'INT' (Control-C) or 'q' (Normal exit/quit).

=cut

#
# API
#

sub run {
    <<'CODE';
    my $repl = Runtime::Debugger->_init;
    while ( 1 ) {
        eval $repl->_step;
    }
CODE
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

=head2 uniq

Return a list of uniq values.

=cut

sub uniq (@) {
    my %h;
    grep { not $h{$_}++ } @_;
}

#
# Internal
#

sub _init {
    my ( $class ) = @_;
    my $self = bless {
        history_file => "$ENV{HOME}/.runtime_debugger.info",
        term         => Term::ReadLine->new( $class ),
    }, $class;
    my $attribs = $self->{attribs} = $self->{term}->Attribs;

    $self->{term}->ornaments( 0 );    # Remove underline from terminal.

    # Restore last history.
    if ( -e $self->{history_file} ) {
        my @history;
        open my $fh, '<', $self->{history_file} or die $!;
        while ( <$fh> ) {
            chomp;
            push @history, $_;
        }
        close $fh;
        $self->_history( @history );
    }

    # https://metacpan.org/pod/Term::ReadLine::Gnu#Custom-Completion
    # Definition for list_completion_function is here: Term/ReadLine/Gnu/XS.pm
    $attribs->{completion_entry_function} =
      $attribs->{list_completion_function};

    # Remove these as break chars so that we can complete:
    # "$scalar", "@array", "%hash"
    # ("%" was already not in the list).
    $attribs->{completer_word_break_characters} =~ s/ [\$@] //xg;

    # Setup some signal hnndling.
    for my $signal ( qw( INT TERM HUP ) ) {
        $SIG{$signal} = sub { $self->_exit( $signal ) };
    }

    $self;
}

sub _exit {
    my ( $self, $how ) = @_;

    # Save current history.
    open my $fh, '>', $self->{history_file} or die $!;
    say $fh $_ for $self->_history;
    close $fh;

    # This will reset the terminal similar to
    # what these should do:
    # - "reset"
    # - "tset"
    # - "stty echo"
    $self->{term}->deprep_terminal;

    die "Exit via '$how'\n";
}

sub _history {
    my $self = shift;

    # Setter.
    return $self->{term}->SetHistory( @_ ) if @_;

    # Getter.
    # Last command should be the first you see upon hiting arrow up
    # and also without any duplicates.
    reverse uniq reverse $self->{term}->GetHistory;
}

sub _step {
    my ( $self ) = @_;

    # Current lexical variables in scope.
    my $lexicals = peek_my( 1 );
    my @words    = sort keys %$lexicals;
    $self->{attribs}->{completion_word} = \@words;

    my $input = $self->{term}->readline( "perl>" ) // '';

    $self->_exit( $input ) if $input eq 'q';

    $input;
}

=head1 SEE ALSO

=head2 L<https://metacpan.org/pod/Devel::REPL>

Great extendable module!

Unfortunately, I did not find a way to get the lexical variables
in a scope. (maybe missed a plugin?!)

=head2 L<https://metacpan.org/pod/Reply>

This module also looked nice, but same issue.

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


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2022 by Tim Potapov.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1;    # End of Runtime::Debugger
