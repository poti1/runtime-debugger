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
use Term::ANSIColor   qw( colored );
use PadWalker         qw( peek_my  peek_our );
use Scalar::Util      qw( blessed reftype );
use Module::Functions qw( get_full_functions );
use Class::Tiny       qw( term attr debug );
use feature           qw( say state );
use parent            qw( Exporter );
use subs              qw( p uniq );

our $VERSION = '0.07';
our @EXPORT  = qw( run h p );

=head1 NAME

Runtime::Debugger - Easy to use REPL with existing lexicals support.

=head1 SYNOPSIS

tl;dr - Easy to use REPL with existing lexicals support.

(empahsis on "existing" since I have not yet found this support
in others modules).

Try with this command line:

 perl -MRuntime::Debugger -E 'my $str1 = "Func"; our $str2 = "Func2"; my @arr1 = "arr-1"; our @arr2 = "arr-2"; my %hash1 = qw(hash 1); our %hash2 = qw(hash 2); my $coderef = sub { "code-ref: @_" }; {package My; sub Func{"My-Func"} sub Func2{"My-Func2"}} my $obj = bless {}, "My"; eval run; say $@'

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
wherever you need like so:

    use Runtime::Debugger;
    eval run;                # Not sure how to avoid using eval here while
                             # keeping access to the top level lexical scope.
                             # (Maybe through abuse of PadWalker and modifying
                             # input dynamically.)
                             # Any ideas ? :)

Press tab to autocomplete any lexical variables in scope (where "eval run" is found).

Saves history locally.

Can use 'p' to pretty print a variable or structure.

=head2 New Variables

Currently its not possible to create any new lexicals variables
while I have not yet found a way to run "eval" with a higher scope of lexicals.
(perhaps there is another way?)

You can make global variables though if:

 - By default ($var=123)
 - Using our (our $var=123)
 - Given the full path ($My::var = 123)

=head1 SUBROUTINES/METHODS

=cut

# Initialize

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

sub _init {
    my ( $class ) = @_;

    # Setup the terminal.
    my $term    = Term::ReadLine->new( $class );
    my $attribs = $term->Attribs;
    $term->ornaments( 0 );    # Remove underline from terminal.

    # Removed these as break chars so that we can complete:
    # "$scalar", "@array", "%hash" ("%" was already not in the list).
    #
    # Removed ">" to be able to complete for method calls: "$obj->$method"
    #
    # TODO: After testing is setup, try removing ">$@".
    $attribs->{completer_word_break_characters} =~ s/ [>] //xg;
    $attribs->{special_prefixes} = '$@%&';

    # Build the debugger object.
    my $self = bless {
        history_file => "$ENV{HOME}/.runtime_debugger.info",
        term         => $term,
        attr         => $attribs,
        debug        => $ENV{RUNTIME_DEBUGGER_DEBUG} // 0,
    }, $class;

   # https://metacpan.org/pod/Term::ReadLine::Gnu#Custom-Completion
   # Definition for list_completion_function is here: Term/ReadLine/Gnu/XS.pm
   # $attribs->{completion_entry_function} = sub { $self->_complete_OLD( @_ ) };
    $attribs->{attempted_completion_function} = sub { $self->_complete( @_ ) };

    $self->_restore_history;

    # Setup some signal hnndling.
    for my $signal ( qw( INT TERM HUP ) ) {
        $SIG{$signal} = sub { $self->_exit( $signal ) };
    }

    $self;
}

# Completion

sub _complete {
    my $self = shift;
    my ( $text, $line, $start, $end ) = @_;
    say ""                  if $self->debug;
    $self->_dump_args( @_ ) if $self->debug;

    # Note: return list is what will be shown as possiblities.

    # Empty - show commands and variables.
    return $self->_complete_empty( @_ ) if $line =~ / ^ \s* $ /x;

    # Help or History command - complete the word.
    return $self->_complete_h( @_ ) if $line =~ / ^ \s* h \w* $ /x;

    # Print command - space afterwards.
    return $self->_complete_p( @_ ) if $line =~ / ^ \s* p $ /x;

    # Method call or coderef - append "(".
    return $self->_complete_arrow( "$1", "$2", @_ )
      if $text =~ / ^ ( \$ \S+ ) -> (\S*) $ /x;

    # Hash or hashref - Show possible keys and string variables.
    return $self->_complete_hash( "$1", @_ )
      if substr( $line, 0, $end ) =~ / (\S+)->\{ [^}]* $ /x;

    # Otherwise assume its a variable.
    return $self->_complete_vars( @_ );
}

sub _complete_empty {
    my $self = shift;
    my ( $text, $line, $start, $end ) = @_;
    $self->_dump_args( @_ ) if $self->debug;

    $self->_match(
        words   => $self->{commands_and_variables},
        partial => $text,
    );
}

sub _complete_h {
    my $self = shift;
    my ( $text, $line, $start, $end ) = @_;
    $self->_dump_args( @_ ) if $self->debug;

    $self->_match(
        partial => $text,
        words   => [ "help", "hist" ],
        nospace => 1,
    );
}

sub _complete_p {
    my $self = shift;
    my ( $text, $line, $start, $end ) = @_;
    $self->_dump_args( @_ ) if $self->debug;

    $self->_match( words => ["p"] );
}

sub _complete_arrow {
    my $self = shift;
    my ( $var, $partial_method, $text, $line, $start, $end ) = @_;
    my $ref = $self->{peek_all}->{$var} // "";
    $partial_method //= '';
    $self->_dump_args( @_ ) if $self->debug;
    say "ref: $ref"         if $self->debug;

    return if ref( $ref ) ne "REF";    # Coderef or object.

    # Object call or coderef.
    my $obj_or_coderef = $$ref;

    # Object.
    if ( blessed( $obj_or_coderef ) ) {
        say "IS_OBJECT: $obj_or_coderef" if $self->debug;

        my $methods = $self->{methods}{$obj_or_coderef};
        if ( not $methods ) {
            $methods = [ get_full_functions( ref $obj_or_coderef ) ];
            $self->{methods}{$obj_or_coderef} = $methods;

            # push @$methods, "(";    # Access as method or hash refs.
            push @$methods, "{" if reftype( $obj_or_coderef ) eq "HASH";
            push @$methods, @{ $self->{vars_string} };

            # push @$methods, $self->{vars_all}; # TODO: Add scalars.
        }
        say "methods: @$methods" if $self->debug;

        return $self->_match(
            words   => $methods,
            partial => $partial_method,
            prepend => "$var->",
            nospace => 1,
        );
    }

    # Coderef.
    if ( ref( $obj_or_coderef ) eq "CODE" ) {
        say "IS_CODE: $obj_or_coderef" if $self->debug;
        return $self->_match(
            words   => ["("],
            prepend => "$text",
            nospace => 1,
        );
    }

    say "NOT OBJECT or CODEREF: $obj_or_coderef" if $self->debug;
    return;
}

sub _complete_hash {
    my $self = shift;
    my ( $var, $text, $line, $start, $end ) = @_;
    $self->_dump_args( @_ ) if $self->debug;

    my @hash_keys = @{ $self->{vars_string} };
    my $ref       = $self->{peek_all}{$var};
    $ref = $$ref if reftype( $ref ) eq "REF";
    push @hash_keys, keys %$ref if reftype( $ref ) eq "HASH";

    $self->_match(
        words   => \@hash_keys,
        partial => $text,
        nospace => 1,
    );
}

sub _complete_vars {
    my $self = shift;
    my ( $text, $line, $start, $end ) = @_;
    $self->_dump_args( @_ ) if $self->debug;

    $self->_match(
        words   => $self->{vars_all},
        partial => $text,
        nospace => 1,
    );
}

=head2 _match

Returns the possible matches:

Input:

 words   => ARRAYREF, # What to look for.
 partial => STRING,   # Default: ""  - What you typed so far.
 prepend => "STRING", # Default: ""  - prepend to each possiblity.
 nospace => 0,        # Default: "0" - will not append a space after a completion.

=cut

sub _match {
    my $self  = shift;
    my %parms = @_;
    $self->_dump_args( @_ ) if $self->debug;

    $parms{partial} //= "";
    $parms{prepend} //= "";
    $self->attr->{completion_word}            = $parms{words};
    $self->attr->{completion_suppress_append} = 1 if $parms{nospace};

    map { "$parms{prepend}$_" }
      $self->term->completion_matches( $parms{partial},
        $self->attr->{list_completion_function} );
}

sub _dump_args {
    my $self = shift;
    my $sub  = ( caller( 1 ) )[3];
    $sub =~ s/ ^ .* :: //x;    # Short sub name.
    my $args = join ",", map { defined( $_ ) ? "'$_'" : "undef" } @_;
    printf "%-20s %s\n", $sub, "($args)";
}

sub _define_commands {
    (
        "help",    # Changed in _step to $repl->help().
        "hist",    # Changed in _step to $repl->hist().
        "p",       # Exporting it.
        "q",       # Exporting it.
    );
}

sub _setup_vars {
    my ( $self ) = @_;

    # Get and cache the current variables in the invoking scope.
    #
    # Note: this block was originally in _step since the intent
    # was to be able to see newly added lexicals or globals.
    # (which does not seem to be possible since the lexical scope
    # of a new variable would be found to the eval block).
    #
    # Although globals can be created, they would appear in the
    # invoking scope (like "main").
    #
    # Moved here to be able to capture the debugger object "$repl".
    #
    # CAUTION: avoid having the same name for a lexical and global
    # variable since the last variable declared would "win".
    my $levels       = 2;    # How many levels until at "$repl=" or main.
    my $peek_my      = peek_my( $levels );
    my $peek_our     = peek_our( $levels );
    my %peek_all     = ( %$peek_our, %$peek_my );
    my @vars_lexical = sort keys %$peek_my;
    my @vars_global  = sort keys %$peek_our;
    my @vars_all     = sort uniq @vars_lexical, @vars_global;

    # Cache variables.
    $self->{peek_my}      = $peek_my;
    $self->{peek_our}     = $peek_our;
    $self->{peek_all}     = \%peek_all;
    $self->{vars_lexical} = \@vars_lexical;
    $self->{vars_global}  = \@vars_global;
    $self->{vars_all}     = \@vars_all;

    my @commands = $self->_define_commands;

    $self->{commands}               = \@commands;
    $self->{commands_and_variables} = [ sort( @commands, @vars_all ) ];

    # Separate variables by types.
    for ( @vars_all ) {
        if ( / ^ \$ /x ) {
            push @{ $self->{vars_scalar} }, $_;

            my $ref  = $peek_all{$_};
            my $type = ref( $ref );
            if ( $type eq "SCALAR" ) {
                push @{ $self->{vars_string} }, $_;
            }
            elsif ( $type eq "REF" ) {
                push @{ $self->{vars_ref} }, $_;
                if ( blessed( $$ref ) ) {
                    push @{ $self->{vars_obj} }, $_;
                }
                elsif ( ref( $$ref ) eq "CODE" ) {
                    push @{ $self->{vars_code} }, $_;
                }
                else {
                    push @{ $self->{vars_ref_else} }, $_;
                }
            }
            else {
                push @{ $self->{vars_scalar_else} }, $_;
            }
        }
        elsif ( / ^ \@ /x ) {
            push @{ $self->{vars_array} }, $_;
        }
        elsif ( / ^ % /x ) {
            push @{ $self->{vars_hash} }, $_;
        }
        else {
            push @{ $self->{vars_else} }, $_;
        }
    }

    $self;
}

sub _step {
    my ( $self ) = @_;

    $self->_setup_vars if not $self->{vars_all};

    my $input = $self->term->readline( "perl>" ) // '';
    say "input_after_readline=[$input]" if $self->debug;

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
              help
            | hist
        ) \b
        (.*)
    $ /\$repl->$1($2)/x;

    $self->_exit( $input ) if $input eq 'q';

    say "input_after_step=[$input]" if $self->debug;
    $input;
}

# Help

=head2 help

Show help section.

=cut

sub help {
    my ( $self ) = @_;
    my $version  = $self->VERSION;
    my $class    = ref $self;

    # TODO: Make colorful.

    say colored( <<"HELP", "YELLOW" );

 $class $version

 <TAB>       - Show options.
 help        - Show this help section.
 hist [N=20] - Show last N commands.
 p DATA [#N] - Prety print data (with optional depth),
 q           - Quit debugger.

HELP
}

# History

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

    if ( @history and $levels < @history ) {
        @history = splice @history, -$levels;
    }

    for my $index ( 0 .. $#history ) {
        printf "%s %s\n",
          colored( $index + 1,       "YELLOW" ),
          colored( $history[$index], "GREEN" );
    }
}

sub _history {
    my $self = shift;

    # Setter.
    return $self->term->SetHistory( @_ ) if @_;

    # Getter.
    # Last command should be the first you see upon hiting arrow up
    # and also without any duplicates.
    my @history = reverse uniq reverse $self->term->GetHistory;
    pop @history
      if @history and $history[-1] eq "q";    # Don't record quit command.

    $self->term->SetHistory( @history );

    @history;
}

sub _restore_history {
    my ( $self ) = @_;
    my @history;

    # Restore last history.
    if ( -e $self->{history_file} ) {
        open my $fh, '<', $self->{history_file} or die $!;
        while ( <$fh> ) {
            chomp;
            push @history, $_;
        }
        close $fh;
    }

    @history = ( "q" ) if not @history;    # avoid blank history.
    $self->_history( @history );
}

sub _save_history {
    my ( $self ) = @_;

    # Save current history.
    open my $fh, '>', $self->{history_file} or die $!;
    say $fh $_ for $self->_history;
    close $fh;
}

# Print

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

# List Utils.

sub uniq (@) {
    my %h;
    grep { not $h{$_}++ } @_;
}

# Cleanup

sub _exit {
    my ( $self, $how ) = @_;

    $self->_save_history;

    die "Exit via '$how'\n";
}

sub Term::ReadLine::DESTROY {
    my ( $self ) = @_;

    # Make sure to fix the terminal incase of errors.
    # This will reset the terminal similar to
    # what these should do:
    # - "reset"
    # - "tset"
    # - "stty echo"
    #
    # Using this DESTROY function since "$self->{term}"
    # is already destroyed by the time we call "_exit".
    $self->deprep_terminal;
}

sub _show_error {
    my ( $self, $error ) = @_;

    # Remove eval line numbers.
    $error =~ s/ at \(eval .+//;

    say colored( $error, "RED" );
}

# Pod

=head2 attr

Internal use.

=head2 debug

Internal use.

=head2 term

Internal use.

=head1 ENVIRONMENT

Install required library:

 sudo apt install libreadline-dev

Enable this environmental variable to show debugging information:

 RUNTIME_DEBUGGER_DEBUG=1

=head1 SEE ALSO

=head2 L<https://metacpan.org/pod/Devel::REPL>

Great extendable module!

Unfortunately, I did not find a way to get the lexical variables
in a scope. (maybe I missed a plugin?!)

=head2 L<https://metacpan.org/pod/Reply>

This module also looked nice, but same issue.

=head1 AUTHOR

Tim Potapov, C<< <tim.potapov[AT]gmail.com> >> E<0x1f42a>E<0x1f977>

=head1 BUGS

- L<no new lexicals|/New Variables>

Please report any (other) bugs or feature requests to L<https://github.com/poti1/runtime-debugger/issues>.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Runtime::Debugger


You can also look for information at:

L<https://metacpan.org/pod/Runtime::Debugger>
L<https://github.com/poti1/runtime-debugger>


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2022 by Tim Potapov.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

"\x{1f42a}\x{1f977}"
