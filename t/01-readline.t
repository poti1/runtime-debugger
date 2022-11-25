#!perl
use 5.006;
use strict;
use warnings;
use Test::More tests => 53;
use Runtime::Debugger;
use Term::ANSIColor qw( colorstrip );
use feature         qw(say);


#
# Setup Debugger.
#

my $RUN;                                # Input: string, Output: data structure.
my $repl = Runtime::Debugger->_init;    # Scope recorded during first "_step".
my $INSTR;                              # Simulated input string.
my $completion_return;                  # Possible completions.

# Special keyboard mappings.
my $EOL     = "\cM";    # Append to string to trigger end of line.
my $TAB     = "\cI";    # Add to string to autocomplete.
my $TAB_ALL = "\cI\e*"; # Add to string to autocomplete plus insert all matches.
                        # This calls "_complete" multiple times.

sub _setup_testmode_debugger {

    $Runtime::Debugger::VERSION = "0.01";    # To make testing version easier.

    # Use a separate history file.
    my $history_file = "$ENV{HOME}/.runtime_debugger_testmode.info";
    unlink $history_file if -e $history_file;
    $repl->{history_file} = $history_file;
    $repl->_restore_history;

    # Avoiding the use of getc for testing.
    $repl->attr->{getc_function} = sub {
        return 0 if not $INSTR;
        my $char;
        ( $char, $INSTR ) = $INSTR =~ / ^ (.) (.*) $ /x;
        ord $char;
    };

    # Wrapper arround the main completion function to capture
    # the results from "_complete".
    # (Its a bit tricky to capture the completions).
    $repl->attr->{attempted_completion_function} = sub {
        my ( $text, @possible ) = $repl->_complete( @_ );
        $completion_return = [@possible];    # Save possible completions.
        ( $text, @possible );    # Return like normally would happen.
    };

    # Do not show prompt messages.
    open my $NULL, ">", "/dev/null" or die $!;
    $repl->attr->{outstream} = $NULL;
}

sub _get_expected_vars {
    {
        commands               => [ 'help', 'hist', 'p', 'q' ],
        commands_and_variables => [
            '$EOL',         '$INSTR',
            '$RUN',         '$TAB',
            '$TAB_ALL',     '$completion_return',
            '$eval_return', '$my_coderef',
            '$my_obj',      '$my_str',
            '$our_coderef', '$our_obj',
            '$our_str',     '$repl',
            '$stdin',       '$stdout',
            '$step_return', '%my_hash',
            '%our_hash',    '@my_arr',
            '@our_arr',     'help',
            'hist',         'p',
            'q'
        ],
        debug        => 0,
        history_file => "$ENV{HOME}/.runtime_debugger_testmode.info",

        # peek_all               => 'HASH(0x55e5a86f9148)',
        # peek_my                => 'HASH(0x55e5a873f7f8)',
        # peek_our               => 'HASH(0x55e5a873fcd8)',
        vars_all => [
            '@our_arr',     '%our_hash',
            '$our_str',     '$our_obj',
            '$our_coderef', '@my_arr',
            '%my_hash',     '$step_return',
            '$stdout',      '$stdin',
            '$repl',        '$my_str',
            '$my_obj',      '$my_coderef',
            '$eval_return', '$completion_return',
            '$TAB_ALL',     '$TAB',
            '$RUN',         '$INSTR',
            '$EOL'
        ],
        vars_array  => [ '@our_arr',     '@my_arr' ],
        vars_code   => [ '$our_coderef', '$RUN' ],
        vars_global =>
          [ '$our_coderef', '$our_obj', '$our_str', '%our_hash', '@our_arr' ],
        vars_hash    => [ '%our_hash', '%my_hash' ],
        vars_lexical => [
            '$EOL',         '$INSTR',
            '$RUN',         '$TAB',
            '$TAB_ALL',     '$completion_return',
            '$eval_return', '$my_coderef',
            '$my_obj',      '$my_str',
            '$repl',        '$stdin',
            '$stdout',      '$step_return',
            '%my_hash',     '@my_arr'
        ],
        vars_obj => [ '$our_obj', '$repl' ],
        vars_ref =>
          [ '$our_obj', '$our_coderef', '$repl', '$completion_return', '$RUN' ],
        vars_ref_else => ['$completion_return'],
        vars_scalar   => [
            '$our_str',     '$our_obj',
            '$our_coderef', '$step_return',
            '$stdout',      '$stdin',
            '$repl',        '$my_str',
            '$my_obj',      '$my_coderef',
            '$eval_return', '$completion_return',
            '$TAB_ALL',     '$TAB',
            '$RUN',         '$INSTR',
            '$EOL'
        ],
        vars_string => [
            '$our_str', '$step_return', '$stdout',     '$stdin',
            '$my_str',  '$my_obj',      '$my_coderef', '$eval_return',
            '$TAB_ALL', '$TAB',         '$INSTR',      '$EOL'
        ],
    };
}

sub _test_repl_vars {

    # Test specific repl keys.
    my $expected = _get_expected_vars();

    for ( sort keys %$expected ) {
        is_deeply $repl->{$_}, $expected->{$_}, "repl->{$_} is correct"
          or say explain $repl->{$_};
    }
}


#
# Sample packages to test out the readline function.
#

{

    package MyObj;

    sub Func1 { "My-Func1" }
    sub Func2 { "My-Func2" }
}

{

    package MyTest;

    use Runtime::Debugger;    # to be able to use: "run", "h", "p".

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

            $step_return = $repl->_step;
            $eval_return = eval $step_return // "";
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
}


#
# Test cases.
#

# Test repl strucure.
_setup_testmode_debugger();
$RUN->();    # Run once to setup variables for testing (like "vars_all").
_test_repl_vars();

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
        todo       => INT,      # Default: 0 (Mark the case as not ready).
        debug      => INT,      # Default: 0 (Enable debugging for one case).
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
    {
        name             => 'Help - short "h"',
        input            => 'h',
        expected_results => {
            line   => 'h',
            stdout => [],
        },
    },
    {
        name             => 'Help - short "h<TAB>"',
        input            => 'h' . $TAB,
        expected_results => {
            comp   => [ 'help', 'hist' ],
            line   => 'h',
            stdout => [],
        },
    },
    {
        name             => 'Help - upon running _step first time',
        input            => '',
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
        todo => 1,
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


    #
    # Scalars.
    #

    # All scalars.
    {
        name             => 'Scalar sigil - all scalars"',
        input            => '$' . $TAB,
        expected_results => {
            comp => $repl->{vars_scalar},

            # Should include all: $scalar $array $hash $arrayref $hashref.
        },
        todo => 1,
    },

    # Arrow - Code reference.
    {
        name             => 'Arrow - coderef "$my->("',
        input            => '$my_coderef->' . $TAB,
        expected_results => {
            line   => '$my_coderef->(',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Arrow - coderef "$our->("',
        input            => '$our_coderef->' . $TAB,
        expected_results => {
            line   => '$our_coderef->(',
            stdout => [],
        },
    },

    # Arrow - Method call.
    {
        name  => 'Scalar Sigil, Arrow - method "$my->(" before closing ")"',
        input => '$my_coderef->' . $TAB . ')',
        expected_results => {
            line   => '$our_coderef->()',
            stdout => [],
        },
        todo => 1,
    },
    {
        name  => 'Scalar Sigil, Arrow - method "$our->(" before closing ")"',
        input => '$our_coderef->' . $TAB . ')',
        expected_results => {
            line   => '$our_coderef->()',
            stdout => [],
        },
    },


    #
    # Arrays
    #

    # All arrays.
    {
        name             => 'Array sigil - all arrays"',
        input            => '@' . $TAB,
        expected_results => {
            comp => $repl->{vars_array},

            # Should include all: @array @hash
        },
        todo => 1,
    },

    # Append (optional) arrow and bracket.
    {
        name             => 'Scalar Sigil - array "$my["',
        input            => '$my_array' . $TAB,
        expected_results => {
            line   => '$my_array[',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil - array "$our["',
        input            => '$our_array' . $TAB,
        expected_results => {
            line   => '$our_array[',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil, Arrow - arrayref "$my->["',
        input            => '$my_arrayref->' . $TAB,
        expected_results => {
            line   => '$my_arrayref->{',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil, Arrow - arrayref "$our->["',
        input            => '$our_arrayref->' . $TAB,
        expected_results => {
            line   => '$our_arrayref->{',
            stdout => [],
        },
        todo => 1,
    },

    # Array slice.

    # Hash slice.

    #
    # Hashs.
    #

    # All hashs.
    {
        name             => 'Hash sigil - all hashs"',
        input            => '%' . $TAB,
        expected_results => {
            comp => $repl->{vars_hash},

            # Should include all: %hash
        },
        todo => 1,
    },

    # Append (optional) arrow and brace.
    {
        name             => 'Scalar Sigil- hash "$my{"',
        input            => '$my_hash{' . $TAB,
        expected_results => {
            comp   => [],
            line   => '$my_hash{',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil- hash "$our{"',
        input            => '$our_hash{' . $TAB,
        expected_results => {
            comp   => [],
            line   => '$our_hash{',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil, Arrow - hashref "$my->{"',
        input            => '$my_hashref->' . $TAB,
        expected_results => {
            line   => '$my_hashref->{',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil, Arrow - hashref "$our->{"',
        input            => '$our_hashref->' . $TAB,
        expected_results => {
            line   => '$our_hashref->{',
            stdout => [],
        },
        todo => 1,
    },

    # Append (optional) arrow, brace - keys
    {
        name             => 'Scalar Sigil, Arrow - hash "$my{"',
        input            => '$my_hash' . $TAB,
        expected_results => {
            line   => '$my_hash{',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil, Arrow - hash "$our{"',
        input            => 'our_hash' . $TAB,
        expected_results => {
            line   => '$our_hash{',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil, Arrow - hashref "$my->{KEYS"',
        input            => '$my_hashref->{' . $TAB,
        expected_results => {
            comp   => [],
            line   => '$my_hashref->{',
            stdout => [],
        },
        todo => 1,
    },
    {
        name             => 'Scalar Sigil, Arrow - hashref "$our->{KEYS"',
        input            => '$our_hashref->{' . $TAB,
        expected_results => {
            comp   => [],
            line   => '$our_hashref->{',
            stdout => [],
        },
        todo => 1,
    },

);

for my $case ( @cases ) {

    # Run the debugger with an input string and capture all the results.
    $repl->debug( 1 ) if $case->{debug};
    my $results_all = $RUN->( $case->{input} );
    $repl->debug( 0 ) if $case->{debug};

    # Update the results.
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
    my $expected_results = $case->{expected_results};
    my @keys             = keys %$expected_results;
    @results{@keys} = @$results_all{@keys};

    # Compare.
    my $fail;
  TODO: {
        local $TODO = $case->{name} if $case->{todo};

        # todo_skip $case->{name}, 1 if $case->{todo};
        $fail = not is_deeply \%results, $expected_results, $case->{name};
    }

    # Error dump.
    if ( $case->{debug} or ( $fail and !$case->{todo} ) ) {
        say "";
        say "GOT:";
        say explain $results_all;

        say "";
        say "EXPECT:";
        say explain $expected_results;

        last;
    }
}

