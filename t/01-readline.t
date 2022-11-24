#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Term::ANSIColor qw( colorstrip );
use feature         qw(say);

BEGIN {
    use_ok( 'Runtime::Debugger' ) || print "Bail out!\n";
}

my $EOL     = "\cM";    # Append to string to trigger end of line.
my $TAB     = "\cI";    # Add to string to autocomplete.
my $TAB_ALL = "\cI\e*"; # Add to string to autocomplete plus insert all matches.
                        # This calls "_complete" multiple times.
my $RUN;
my $repl;

# Sample package to test out the readline function.
{

    package MyObj;

    sub Func1 { "My-Func1" }
    sub Func2 { "My-Func2" }
}

{

    package MyTest;

    # Lexical variables.
    my $my_str     = "Func1";
    my @my_arr     = "arr-my";
    my %my_hash    = qw(hash my);
    my $my_coderef = sub { "coderef-my: @_" };
    my $my_obj     = bless { type => "my" }, "MyObj";

    # Global variables.
    our $our_str     = "Func2";
    our @our_arr     = "arr-our";
    our %our_hash    = qw(hash our);
    our $our_coderef = sub { "coderef-our: @_" };
    our $our_obj     = bless { type => "our" }, "MyObj";

    #
    # Setup Debugger.
    #

    use Runtime::Debugger;

    $Runtime::Debugger::VERSION  = "0.01";    # To make testing easier.
    $ENV{RUNTIME_DEBUGGER_DEBUG} = 0;         # Just for debugging the test.
    $repl                        = Runtime::Debugger->_init;

    # Use separate history file.
    my $history_file = "$ENV{HOME}/.runtime_debugger_testmode.info";
    unlink $history_file if -e $history_file;
    $repl->{history_file} = $history_file;
    $repl->_restore_history;

    # Avoid using getc for testing (to not have prompts).
    my $INSTR;
    $repl->attr->{getc_function} = sub {
        return 0 if not $INSTR;
        my $char;
        ( $char, $INSTR ) = $INSTR =~ / ^ (.) (.*) $ /x;
        ord $char;
    };

    # Signals that a new character can be read from readline.
    # $repl->attr->{input_available_hook} = sub { 1 };

    # Wrapper arround the main completion function to capture
    # the results from "_complete".
    my $completion_return;
    $repl->attr->{attempted_completion_function} = sub {
        my ( $text, $line, $start, $end ) = @_;
        my @ret   = $repl->_complete( @_ );
        my @words = @ret;
        shift @words;    # Skip exisiing text.
        $completion_return = \@words;
        @ret;
    };

    # my $completion_return_hook;
    # $repl->attr->{completion_display_matches_hook} = sub {
    #     my ( $matches, $num_matches, $max_length ) = @_;
    #     say "matches_hook:";
    #     p \@_, "--maxdepth=0";
    #     $repl->term->display_match_list( $matches );
    #     $repl->term->forced_update_display;
    # };

    open my $NULL, ">", "/dev/null" or die $!;

    # Run this coderef in each case to get the Variables
    # in this scope.
    $RUN = sub {
        my ( $stdin ) = @_;
        $stdin //= "";
        $INSTR = $stdin . $EOL;

        my $step_return;
        my $eval_return;
        my $stdout = "";
        $completion_return = [];

        # Run while capturing terminal output.
        {
            local *STDOUT;
            local *STDERR;
            open STDOUT, ">",  \$stdout or die $!;
            open STDERR, ">>", \$stdout or die $!;

            $repl->attr->{outstream} = $NULL;
            $step_return             = $repl->_step;
            $eval_return             = eval $step_return // "";
            chomp $stdout;
        }

        return {
            stdin  => $stdin,
            comp   => $completion_return,         # All recursive completions.
            line   => $step_return,
            eval   => $eval_return,
            stdout => [ split /\n/, $stdout ],    # Much easier to debug later.
        };
    };

    # Run once to setup variables for testins (like "vars_all").
    $RUN->();
}

=head1 Sample test case
    
    # This should be enough data to test the module.
    {
        name             => 'STRING',
        input            => 'STRING',
        nocolor          => ARRAYREF, # Keys of values from results to strip colors.
        expected_results => {
            stdin  => 'STRING', # Input.
            comp   => ARRAYREF, # Result of tab completion
                                # (empy if no TAB or not a single choice).
            line   => 'STRING', # Line after "_step", but before "eval".
            eval   => 'STRING', # Evaled line.
            stdout => ARRAYREF, # Result of print split by newlines.
        },
        debug      => NUMBER,   # Default: 0 (Enable debugging for one case).
    },

=cut

my @cases = (

    # Literal.
    {
        name             => 'simple line 1',
        input            => 'abc',
        expected_results => {
            line   => 'abc',
            stdout => [],
        }
    },
    {
        name             => 'simple line 2',
        input            => 'abc2',
        expected_results => {
            line   => 'abc2',
            stdout => [],
        }
    },

    # History - Do these first so case order wont matter for others.
    {
        name             => 'History - default lines',
        input            => 'hist',
        nocolor          => ["stdout"],
        expected_results => {
            stdout => [ '1 q', '2 abc', '3 abc2', '4 hist', ],
        },
    },
    {
        name             => 'History - explicit line to show',
        input            => 'hist 3',
        nocolor          => ["stdout"],
        expected_results => {
            stdout => [ '1 abc2', '2 hist', '3 hist 3' ],
        },
    },
    {
        name             => 'History - complete the command "h"',
        input            => 'h' . $TAB,
        expected_results => {
            comp   => [ "help", "hist" ],
            stdout => [],
        },
    },
    {
        name             => 'History - complete the command "hi"',
        input            => 'hi' . $TAB,
        nocolor          => ["stdout"],
        expected_results => {
            comp   => [],
            line   => '$repl->hist()',
            stdout => [ '1 q', '2 abc', '3 abc2', '4 hist 3', '5 h', '6 hist' ],
        },
    },

    # Empty.
    {
        name             => 'Empty',
        input            => '',
        expected_results => {
            line   => '',
            stdout => [],
        },
    },
    {
        name             => 'Empty TAB completion',
        input            => $TAB,
        expected_results => {
            comp   => $repl->{commands_and_variables},
            stdout => [],
        },
    },

    # Print.
    {
        name             => 'Print literal',
        input            => 'p 123',
        expected_results => {
            line   => 'p 123',
            stdout => ['123'],
        },
    },
    {
        name             => 'Print TAB complete: "p<TAB>"',
        input            => 'p' . $TAB,
        expected_results => {
            line   => 'p ',
            stdout => [],
        },
    },
    {
        name             => 'Print TAB complete: "p<TAB><TAB"',
        input            => 'p' . $TAB . $TAB,
        expected_results => {
            comp   => $repl->{vars_all},
            line   => 'p ',
            stdout => [],
        },
    },
    {
        name             => 'Print TAB complete: "p $<TAB>"',
        input            => 'p $' . $TAB,
        expected_results => {
            comp   => $repl->{vars_scalar},
            stdout => [],
        },
    },
    {
        name             => 'Print TAB complete: p $o ',
        input            => 'p $o' . $TAB,
        expected_results => {
            comp   => [ '$our_str', '$our_obj', '$our_coderef', ],
            stdout => [],
        },
    },
    {
        name  => 'Print TAB complete: p $o<TAB>_ ',
        input => 'p $o' . $TAB . '_',               # Does not expand after tab.
        expected_results => {
            comp   => [ '$our_str', '$our_obj', '$our_coderef', ],
            stdout => [],
        },
    },
    {
        name             => 'Print TAB complete: p $<TAB>_str ',
        input            => 'p $o' . $TAB . '_str',
        expected_results => {
            comp   => [ '$our_str', '$our_obj', '$our_coderef', ],
            stdout => [],
        },
    },

    # Arrow.
    {
        name             => 'Arrow - coderef "$my->("',
        input            => '$my_coderef->' . $TAB,
        expected_results => {
            line   => '$my_coderef->(',
            stdout => [],
        },
        skip => 1,
    },
    {
        name             => 'Arrow - coderef "$our->("',
        input            => '$our_coderef->' . $TAB,
        expected_results => {
            line   => '$our_coderef->(',
            stdout => [],
        },
    },
    {
        name             => 'Arrow - method "$my->(" before closing ")"',
        input            => '$my_coderef->' . $TAB . ')',
        expected_results => {
            line   => '$our_coderef->()',
            stdout => [],
        },
        skip => 1,
    },
    {
        name             => 'Arrow - method "$our->(" before closing ")"',
        input            => '$our_coderef->' . $TAB . ')',
        expected_results => {
            line   => '$our_coderef->()',
            stdout => [],
        },
    },

    # Help.
    {
        name             => 'Help',
        input            => 'help',
        nocolor          => ["stdout"],
        expected_results => {
            line   => '$repl->help()',    # "help" changes to this.
            eval   => '1',                # Return value.
            stdout => [
                '',
                ' Runtime::Debugger 0.01',
                '',
                ' <TAB>       - Show options.',
                ' help        - Show this help section.',
                ' hist [N=20] - Show last N commands.',
                ' p DATA [#N] - Prety print data (with optional depth),',
                ' q           - Quit debugger.',
                '',
                ''
            ],
        },
    },

);

# Signals that a new character can be read from readline.
my $ready_to_read = 0;
$repl->attr->{input_available_hook} = sub { $ready_to_read };

for my $case ( @cases ) {

    # Skip
    if ( $case->{skip} ) {
        pass $case->{name};
        next unless $case->{debug};
    }

    # $ready_to_read = 1;

    # Get results.
    $repl->debug( 1 ) if $case->{debug};
    my $results_all      = $RUN->( $case->{input} );
    my $expected_results = $case->{expected_results};
    my @keys             = keys %$expected_results;
    $repl->debug( 0 ) if $case->{debug};

    # Update results.
    my $nocolor = $case->{nocolor};
    if ( $nocolor and @$nocolor ) {
        for my $key ( @$nocolor ) {
            my $val = $results_all->{$key};
            my $ref = ref $val;
            if ( $ref eq "SCALAR" ) {
                $results_all->{$key} = colorstrip( $val );
            }
            elsif ( $ref eq "ARRAY" ) {
                $_ = colorstrip( $_ ) for @$val;
            }
            else {
                warn "Cannot apply 'nocolor' due to unsupport type '$ref'\n";
                p $results_all;
            }
        }
    }

    # Limit results to expected_results.
    my %results;
    @results{@keys} = @$results_all{@keys};

    # Compare.
    my $success = is_deeply \%results, $expected_results, $case->{name};

    # Error dump.
    if ( not $success or $case->{debug} ) {
        say "";
        say "GOT:";
        p $results_all, "--maxdepth=0";

        say "";
        say "EXPECT:";
        p $expected_results, "--maxdepth=0";

        last;
    }
}

# Explicitly stop the debugger.
# Will write history to a file.
# eval { $repl->_exit( "test" ) };

done_testing( 21 );
