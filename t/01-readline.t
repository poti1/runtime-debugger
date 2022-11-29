#!perl

package MyObj;

sub Func1 { "My-Func1" }
sub Func2 { "My-Func2" }


package MyTest;

use 5.006;
use strict;
use warnings;
use Test::More tests => 65;
use Runtime::Debugger;
use Term::ANSIColor qw( colorstrip );
use feature         qw( say );

#
# Test variables.
#

# Lexical variables.
my $my_str      = "Func1";
my @my_array    = "array-my";
my $my_arrayref = ["array-my"];
my %my_hash     = qw(key1 a key2 b);
my $my_hashref  = {qw(key1 a key2 b)};
my $my_coderef  = sub { "coderef-my: @_" };
my $my_obj      = bless { type => "my" }, "MyObj";

# Global variables.
our $our_str      = "Func2";
our @our_array    = "array-our";
our $our_arrayref = ["array-our"];
our %our_hash     = qw(key11 aa key22 bb);
our $our_hashref  = {qw(key11 aa key22 bb)};
our $our_coderef  = sub { "coderef-our: @_" };
our $our_obj      = bless { type => "our" }, "MyObj";

# eval run;
# exit;

my $INSTR;                # Simulated input string.
my $COMPLETION_RETURN;    # Possible completions.
my $repl = MyTest->_setup_testmode_debugger();

sub _setup_testmode_debugger {

    my $_repl = Runtime::Debugger->_init; # Scope recorded during first "_step".
    $Runtime::Debugger::VERSION = "0.01";  # To make testing the version easier.

    # Use a separate history file.
    my $history_file = "$ENV{HOME}/.runtime_debugger_testmode.info";
    unlink $history_file if -e $history_file;
    $_repl->{history_file} = $history_file;
    $_repl->_restore_history;

    # Avoiding the use of getc for testing.
    $_repl->attr->{getc_function} = sub {
        return 0 if not $INSTR;
        my $char;
        ( $char, $INSTR ) = $INSTR =~ / ^ (.) (.*) $ /x;
        ord $char;
    };

    # Wrapper arround the main completion function to capture
    # the results from "_complete".
    # (Its a bit tricky to capture the completions).
    $_repl->attr->{attempted_completion_function} = sub {
        my ( $text, @possible ) = $_repl->_complete( @_ );
        $COMPLETION_RETURN = [@possible];    # Save possible completions.
        ( $text, @possible );    # Return like normally would happen.
    };

    # Do not show prompt messages.
    open my $NULL, ">", "/dev/null" or die $!;
    $_repl->attr->{outstream} = $NULL;

    $_repl;
}

sub _define_expected_vars {
    my ( $_repl ) = @_;

    {
        commands              => [ 'help', 'hist', 'p', 'q' ],
        commands_and_vars_all => [
            '$INSTR',
            '$TAB',
            '$TAB_ALL', '$COMPLETION_RETURN',
            '$my_array',
            '$my_arrayref', '$my_coderef',
            '$my_hash',     '$my_hashref',
            '$my_obj',      '$my_str',
            '$our_array',   '$our_arrayref',
            '$our_coderef', '$our_hash',
            '$our_hashref', '$our_obj',
            '$our_str',     '$repl',

            '%my_hash',
            '%our_hash', '@my_array',
            '@my_hash',  '@our_array',
            '@our_hash', 'help',
            'hist',      'p',
            'q'
        ],
        debug        => 0,
        history_file => "$ENV{HOME}/.runtime_debugger_testmode.info",

        # TODO: uncomment.
        # Need to remove coderefs and objects first though.
        #
        # peek_all               => 'HASH(0x55e5a86f9148)',
        # peek_my                => 'HASH(0x55e5a873f7f8)',
        # peek_our => {
        #     '$our_str'  => 'Func2',
        #     '%our_hash' => {
        #         'hash' => 'our'
        #     },
        #     '@our_array' => ['array-our']
        # },
        vars_all => [
            '$INSTR',
            '$TAB',
            '$TAB_ALL', '$COMPLETION_RETURN',
            '$my_array',
            '$my_arrayref', '$my_coderef',
            '$my_hash',     '$my_hashref',
            '$my_obj',      '$my_str',
            '$our_array',   '$our_arrayref',
            '$our_coderef', '$our_hash',
            '$our_hashref', '$our_obj',
            '$our_str',     '$repl',

            '%my_hash',
            '%our_hash', '@my_array',
            '@my_hash',  '@our_array',
            '@our_hash'
        ],
        vars_array    => [ '@our_array', '@my_array' ],
        vars_arrayref => [
            '$our_arrayref',

            # TODO: fix
            # '$my_arrayref',
            '$COMPLETION_RETURN'
        ],
        vars_code   => [ '$our_coderef', ],
        vars_global => [
            '$our_arrayref', '$our_coderef', '$our_hashref', '$our_obj',
            '$our_str',      '%our_hash',    '@our_array'
        ],
        vars_hash    => [ '%our_hash', '%my_hash' ],
        vars_hashref => [
            '$our_hashref',

            # '$my_hashref'
        ],
        vars_lexical => [
            '$INSTR',
            '$TAB',
            '$TAB_ALL', '$COMPLETION_RETURN',
            '$my_arrayref',
            '$my_coderef', '$my_hashref',
            '$my_obj',     '$my_str',
            '$repl',

            '%my_hash', '@my_array'
        ],
        vars_obj => [ '$our_obj', '$repl' ],
        vars_ref => [
            '$our_obj',     '$our_hashref',
            '$our_coderef', '$our_arrayref',
            '$repl',        '$COMPLETION_RETURN',

        ],
        vars_ref_else => [],
        vars_scalar   => [
            '$our_str',     '$our_obj',
            '$our_hashref', '$our_coderef',
            '$our_arrayref',

            '$repl',       '$my_str',
            '$my_obj',     '$my_hashref',
            '$my_coderef', '$my_arrayref',
            '$COMPLETION_RETURN',
            '$TAB_ALL', '$TAB',
            '$INSTR',

        ],
        vars_string => [
            '$our_str',    '$my_str',      '$my_obj',  '$my_hashref',
            '$my_coderef', '$my_arrayref', '$TAB_ALL', '$TAB',
            '$INSTR',
        ],
    };
}

sub _define_help_stdout {
    [
        '',
        ' Runtime::Debugger 0.01',
        '',
        ' <TAB>       - Show options.',
        ' help        - Show this help section.',
        ' hist [N=20] - Show last N commands.',
        ' p DATA [#N] - Prety print data (with optional depth),',
        ' q           - Quit debugger.',
        ''
    ]
}

sub _define_test_cases {
    my ( $_repl ) = @_;

    # Special keyboard mappings.
    my $TAB = "\cI";    # Add to string to autocomplete.
    my $TAB_ALL =
      "\cI\e*";         # Add to string to autocomplete plus insert all matches.
                        # This calls "_complete" multiple times.

    my @cases = (

# # This should be enough data to test the module.
# {
#     name             => 'STRING',
#     input            => 'STRING',
#     nocolor          => ARRAYREF, # Keys of values from results to strip colors.
#     expected_results => {
#         stdin  => 'STRING', # Input.
#         comp   => ARRAYREF, # Result of tab completion
#                             # (empty if no TAB or only a single choice).
#         line   => 'STRING', # Line after "_step", but before "eval".
#         eval   => 'STRING', # Evaled line.
#         stdout => ARRAYREF, # Result of print split by newlines.
#     },
#     todo       => INT,      # Default: 0 (Mark the case as not ready).
#     debug      => INT,      # Default: 0 (Enable debugging for one case).
# },

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
                stdout =>
                  [ '1 q', '2 abc', '3 abc2', '4 hist 3', '5 h', '6 hist' ],
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
                comp   => $_repl->{commands_and_vars_all},
                stdout => [],
            },
        },

        # Help.
        {
            name             => 'Help',
            input            => 'help',
            nocolor          => ["stdout"],
            expected_results => {
                line   => '$repl->help()',         # "help" changes to this.
                eval   => '1',                     # Return value.
                stdout => _define_help_stdout(),
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
                comp   => $_repl->{vars_all},
                line   => 'p ',
                stdout => [],
            },
        },
        {
            name             => 'Print TAB complete: "p $<TAB>"',
            input            => 'p $' . $TAB,
            expected_results => {
                comp   => $_repl->{vars_scalar},
                stdout => [],
            },
            todo => 1,    # Scalar should include $hash and $array ?!
        },
        {
            name             => 'Print TAB complete: p $o ',
            input            => 'p $o' . $TAB,
            expected_results => {
                'comp' => [ grep { / ^ \$o /x } @{ $_repl->{vars_scalar} } ],
                stdout => [],
            },
            todo => 1,    # Scalar should include $hash and $array ?!
                          # debug => 1,
        },
        {
            name  => 'Print TAB complete: p $o<TAB>_ ',
            input => 'p $o' . $TAB . '_',    # Does not expand after tab.
            expected_results => {
                'comp' => [
                    '$our_str',     '$our_obj',
                    '$our_hashref', '$our_coderef',
                    '$our_arrayref'
                ],
                stdout => [],
            },
            todo => 1,    # Scalar should include $hash and $array ?!
        },
        {
            name             => 'Print TAB complete: p $<TAB>_str ',
            input            => 'p $o' . $TAB . '_str',
            expected_results => {
                'comp' => [
                    '$our_str',     '$our_obj',
                    '$our_hashref', '$our_coderef',
                    '$our_arrayref'
                ],
                stdout => [],
            },
            todo => 1,    # Scalar should include $hash and $array ?!
        },


        #
        # Scalars.
        #

        # All scalars.
        {
            name             => 'Scalar sigil - all scalars"',
            input            => '$' . $TAB,
            expected_results => {
                comp => $_repl->{vars_scalar},
            },
            todo => 1,    # Scalar should include $hash and $array ?!
        },

        # Arrow - Code reference.
        {
            name             => 'Arrow - coderef "$my->"',
            input            => '$my_coderef->' . $TAB,
            expected_results => {
                line   => '$my_coderef->(',
                stdout => [],
            },
            todo => 1,    # Only in the test it fails.
        },
        {
            name             => 'Arrow - coderef "$our->"',
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
                line   => '$my_coderef->()',
                stdout => [],
            },
        },
        {
            name => 'Scalar Sigil, Arrow - method "$our->(" before closing ")"',
            input            => '$our_coderef->' . $TAB . ')',
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
                comp => $_repl->{vars_array},
            },
            todo => 1,    # Array should include @hash ?!
        },

        # Complete an array with a "$" or "@" sigil
        {
            name             => 'Complete array - arrayref "$my_"',
            input            => '$my_array' . $TAB,
            expected_results => {
                comp => [ '$my_array', '$my_arrayref' ],
            },
        },
        {
            name             => 'Complete array - arrayref "$our_"',
            input            => '$our_array' . $TAB,
            expected_results => {
                comp => [ '$our_array', '$our_arrayref' ],
            },
        },
        {
            name             => 'Complete array - array "@my_"',
            input            => '@my_arr' . $TAB,
            expected_results => {
                line => '@my_array',
            },
        },
        {
            name             => 'Complete array - array "@our_"',
            input            => '@our_arr' . $TAB,
            expected_results => {
                line => '@our_array',
            },
        },
        {
            name             => 'Complete array - scalar context "$my_array"',
            input            => '$my_array' . $TAB,
            expected_results => {
                comp => [ '$my_array', '$my_arrayref' ],
            },
        },
        {
            name             => 'Complete array - scalar context "$our_array"',
            input            => '$our_array' . $TAB,
            expected_results => {
                comp => [ '$our_array', '$our_arrayref' ],
            },
        },

        # Append bracket after arrow.
        {
            name             => 'Scalar Sigil, Arrow - arrayref "$my->"',
            input            => '$my_arrayref->' . $TAB,
            expected_results => {
                line   => '$my_arrayref->[',
                stdout => [],
            },
        },
        {
            name             => 'Scalar Sigil, Arrow - arrayref "$our->"',
            input            => '$our_arrayref->' . $TAB,
            expected_results => {
                line   => '$our_arrayref->[',
                stdout => [],
            },
        },

        # TAB after arrow and bracket.
        {
            name             => 'Scalar Sigil, Arrow - arrayref "$my->["',
            input            => '$my_arrayref->[' . $TAB,
            expected_results => {
                comp   => $_repl->{vars_all},
                line   => '$my_arrayref->[',
                stdout => [],
            },
        },
        {
            name             => 'Scalar Sigil, Arrow - arrayref "$our->["',
            input            => '$our_arrayref->[' . $TAB,
            expected_results => {
                comp   => $_repl->{vars_all},
                line   => '$our_arrayref->[',
                stdout => [],
            },
        },

        #
        # Hashs.
        #

        # All hashs.
        {
            name             => 'Hash sigil - all hashs"',
            input            => '%' . $TAB,
            expected_results => {
                comp => $_repl->{vars_hash},
            },
        },

        # Complete a hash with a "$" or "@" or "%" sigil
        {
            name             => 'Complete hash - hashref "$my_"',
            input            => '$my_hash' . $TAB,
            expected_results => {
                comp => [ '$my_hash', '$my_hashref' ],
            },
        },
        {
            name             => 'Complete hash - hashref "$our_"',
            input            => '$our_hash' . $TAB,
            expected_results => {
                comp => [ '$our_hash', '$our_hashref' ],
            },
        },
        {
            name             => 'Complete hash - array "@my_"',
            input            => '@my_ha' . $TAB,
            expected_results => {
                comp => ['@my_hash'],
            },
            todo => 1,

            # debug => 1,
        },
        {
            name             => 'Complete hash - array "@our_"',
            input            => '@our_ha' . $TAB,
            expected_results => {
                comp => ['@our_hash'],
            },
            todo => 1,
        },
        {
            name             => 'Complete hash - hash "%my_"',
            input            => '%my_ha' . $TAB,
            expected_results => {
                line => '%my_hash',
            },
        },
        {
            name             => 'Complete hash - hash "%our_"',
            input            => '%our_ha' . $TAB,
            expected_results => {
                line => '%our_hash',
            },
        },
        {
            name             => 'Complete hash - scalar context "$my_hash"',
            input            => '$my_hash' . $TAB,
            expected_results => {
                comp => [ '$my_hash', '$my_hashref' ],
            },
            todo => 1,
        },
        {
            name             => 'Complete hash - scalar context "$our_hash"',
            input            => '$our_hash' . $TAB,
            expected_results => {
                comp => [ '$our_hash', '$our_hashref' ],
            },
            todo => 1,
        },

        # Append brace after arrow.
        {
            name             => 'Scalar Sigil, Arrow - hashref "$my->"',
            input            => '$my_hashref->' . $TAB,
            expected_results => {
                line => '$my_hashref->{',
            },
        },
        {
            name             => 'Scalar Sigil, Arrow - hashref "$our->"',
            input            => '$our_hashref->' . $TAB,
            expected_results => {
                line => '$our_hashref->{',
            },
        },

        # TAB after arrow and brace.
        {
            name             => 'Scalar Sigil, Arrow - hashref "$my->{"',
            input            => '$my_hashref->{' . $TAB,
            expected_results => {
                comp   => [ sort qw(key1 key2), @{ $_repl->{vars_string} } ],
                line   => '$my_hashref->{',
                stdout => [],
            },
        },
        {
            name             => 'Scalar Sigil, Arrow - hashref "$our->{"',
            input            => '$our_hashref->{' . $TAB,
            expected_results => {
                comp   => [ sort qw(key11 key22), @{ $_repl->{vars_string} } ],
                line   => '$our_hashref->{',
                stdout => [],
            },
        },

        # Append key after (optional) arrow, brace.
        {
            name             => 'Scalar Sigil, Arrow - hash "$my{"',
            input            => '$my_hash{' . $TAB,
            expected_results => {
                comp => [ "key1", "key2" ],
                line => '$my_hash{',
            },
            todo => 1,

            # debug => 1,
        },
        {
            name             => 'Scalar Sigil, Arrow - hash "$our{"',
            input            => '$our_hash{' . $TAB,
            expected_results => {
                comp   => [ "key1", "key2" ],
                line   => '$our_hash{',
                stdout => [],
            },
            todo => 1,
        },
        {
            name             => 'Scalar Sigil, Arrow - hashref "$my->{"',
            input            => '$my_hashref->{' . $TAB,
            expected_results => {
                comp   => [ "key1", "key2" ],
                line   => '$my_hashref->{',
                stdout => [],
            },
            todo => 1,
        },
        {
            name             => 'Scalar Sigil, Arrow - hashref "$our->{"',
            input            => '$our_hashref->{' . $TAB,
            expected_results => {
                comp   => [ "key1", "key2" ],
                line   => '$our_hashref->{',
                stdout => [],
            },
            todo => 1,
        },

    );

    @cases;
}

sub init_case {
    {
        name             => 'Help - upon running _step first time',
        input            => '',
        nocolor          => ["stdout"],
        expected_results => {
            line   => '',
            stdout => _define_help_stdout(),
        },
    };
}

sub _run_case {
    my ( $_repl, $case ) = @_;
    my $stdin = $case->{input} // '';
    my $step_return;
    my $eval_return;
    my $stdout = "";
    my $EOL    = "\cM";    # Append to string to trigger end of line.
    $INSTR             = $stdin . $EOL;
    $COMPLETION_RETURN = [];

    $_repl->debug( 1 ) if $case->{debug};

    # Run while capturing terminal output.
    eval {
        local *STDOUT;
        local *STDERR;
        open STDOUT, ">",  \$stdout or die $!;
        open STDERR, ">>", \$stdout or die $!;

        $step_return = $repl->_step;
        $eval_return = eval $step_return // "";
        chomp $stdout;
    };
    $_repl->_show_error( $@ ) if $@;    # Probably a developer issue.

    $_repl->debug( 0 ) if $case->{debug};

    # Run the debugger with an input string and capture all the results.
    my $results_all = {
        stdin  => $stdin,
        comp   => $COMPLETION_RETURN,             # All completions.
        line   => $step_return,
        eval   => $eval_return,
        stdout => [ split /\n/, $stdout, -1 ],    # Much easier to debug later.
    };

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
        $fail = not is_deeply \%results, $expected_results, $case->{name};
    }

    # Error dump.
    my $last;
    if ( $case->{debug} or ( $fail and !$case->{todo} ) ) {
        say "";
        say "GOT:";
        say explain $results_all;

        say "";
        say "EXPECT:";
        say explain $expected_results;

        $last++;
    }

    $last;
}

sub _test_repl_vars {
    my ( $_repl ) = @_;

    # Test specific repl keys.
    my $expected = _define_expected_vars( $_repl );

    for ( sort keys %$expected ) {
        is_deeply $_repl->{$_}, $expected->{$_}, "_repl->{$_} is correct"
          or say explain $_repl->{$_};
    }
}

# Main
_run_case( $repl, init_case() );

# p $repl->{peek_all}, '--maxdepth=2';

# _test_repl_vars($repl);
# exit;

for my $case ( _define_test_cases( $repl ) ) {
    last if _run_case( $repl, $case );
}

