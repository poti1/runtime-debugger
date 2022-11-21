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
use PadWalker       qw( peek_my  peek_our );
use feature         qw( say );
use parent          qw( Exporter );
use subs            qw( p uniq );

our @EXPORT = qw(
  run
  h
  p
  hist
  uniq
);

=head1 NAME

Runtime::Debugger - Easy to use REPL with existing lexicals support.

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';


=head1 SYNOPSIS

tl;dr - Easy to use REPL with existing lexicals support.

(empahsis on "existing" since I have not yet found this support
in others modules).

Try with this command line:

    perl -MRuntime::Debugger -E 'my $str1 = "str-1"; our $str2 = "str-2"; my @arr1 = "arr-1"; our @arr2 = "arr-2"; my %hash1 = qw(hash 1); our %hash2 = qw(hash 2);  eval run; say $@'

=head1 DESCRIPTION

One can usually just do this:

 # Insert this where you want to pause:
 $DB::single = 1;

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

Press tab to autocomplete any lexical variables in scope (where "eval run" is found).

Saves history locally.

Can use 'p' to pretty print a variable or structure.

=head2 New Variables

Currently its not possible to create any new lexicals variables
while I have not yet found a way to run "eval" with a higher scope of lexicals.
(perhaps there is another way?perhaps there is another way?)

You can make global variables though if:

- By default ($var=123)
- Using our (our $var=123)
- Given the full path ($My::var = 123)

=head1 SUBROUTINES/METHODS

=cut

#
# API
#

=head2 run

Runs the REPL (dont forget eval!)

 eval run

Sets C<$@> to the exit reason like 'INT' (Control-C) or 'q' (Normal exit/quit).

=cut

sub run {
    <<'CODE';
    my $repl = Runtime::Debugger->_init;
    while ( 1 ) {
        eval $repl->_step;
        $repl->_show_error($@) if $@;
    }
CODE
}

=head2 h

Show help section.

=cut

sub h {
    say colored( <<"HELP", "YELLOW" );

 h           - Show this help section.
 q           - Quit debugger.
 TAB         - Show available lexical variables.
 p DATA [#N] - Prety print data (with optional depth),
 hist [N=20] - Show last N commands.

HELP
}

=head2 p

Data::Dumper::Dump anything.

 p 123
 p [1, 2, 3]

Can adjust the maxdepth (default is 1) to see with: "#Number".

 p { a => [1, 2, 3] } #1

Output:

 {
   'a' => 'ARRAY(0x55fd914a3d80)'
 }

Set maxdepth to '0' to show all nested structures.

=cut

sub p {

    # Use same function to change maxdepth of whats shown.
    my $maxdepth =
      1;    # Good default to often having to change it during display.
    if ( @_ > 1 and $_[-1] =~ / ^ --maxdepth=(\d+) $ /x )
    {       # Like with "tree" command.
        $maxdepth = $1;
        pop @_;
    }

    my $d = Data::Dumper
      ->new( \@_ )
      ->Sortkeys( 1 )
      ->Terse( 1 )
      ->Indent( 1 )
      ->Maxdepth( $maxdepth );

    return $d->Dump if wantarray;
    print $d->Dump;
}

=head2 hist

Show history of commands.

By default will show 20 commands:

 hist

Same thing:

 hist 20

Can show more:

 hist 50

=cut

sub hist {
    my ( $self, $levels ) = @_;
    $levels //= 20;
    my @history = $self->_history;

    if ( $levels < @history ) {
        @history = splice @history, -$levels;
    }

    for my $index ( 0 .. $#history ) {
        printf "%s %s\n",
          colored( $index + 1,       "YELLOW" ),
          colored( $history[$index], "GREEN" );
    }
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
    # Note: this block could be moved to _init, but the intent
    # was to be able to see newly added lexcicals
    # (which does not seem to be possible).
    #
    # But global variable can be created and therefore it is
    # best to keep this block here to run per command.
    my $lexicals = peek_my( 1 );
    my $globals  = peek_our( 1 );
    my @words    = sort keys %$lexicals, keys %$globals;
    $self->{attribs}->{completion_word} = \@words;

    my $input = $self->{term}->readline( "perl>" ) // '';

    # Change '#1' to '--maxdepth=1'
    if ( $input =~ / ^ p\b /x ) {
        $input =~ s/
            \s*
            \#(\d)     #2 to --maxdepth=2
            \s*
        $ /, '--maxdepth=$1'/x;
    }

    # Change "COMMAND ARG" to "$repl->COMMAND(ARG)".
    $input =~ s/ ^
        (
            hist
        ) \b
        (.*)
    $ /\$repl->$1($2)/x;

    $self->_exit( $input ) if $input eq 'q';

    $input;
}

sub _show_error {
    my ( $self, $error ) = @_;

    # Remove eval line numbers.
    $error =~ s/ at \(eval .+//;

    say colored( $error, "RED" );
}

=head1 ENVIRONMENT

Install required library:

 sudo apt install libreadline-dev

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

- L<no new lexicals|/=head2 New Variables>

Please report any (other) bugs or feature requests to L<https://github.com/poti1/runtime-debugger/issues>.


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
