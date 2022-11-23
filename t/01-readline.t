#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Term::ANSIColor qw( uncolor );
use feature         qw(say);

BEGIN {
    use_ok( 'Runtime::Debugger' ) || print "Bail out!\n";
}

my $EOL = "\cM";      # Append this character to the end to trigger end of line.
my $TAB = "\cI\e*";   # Add this string to trigger completion support.
my $RUN;
my $repl;

# Sample package to test out the readline function.
package MyObj {
    sub Func1 { "My-Func1" }
    sub Func2 { "My-Func2" }
}

package MyTest {

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

    $repl = Runtime::Debugger->_init;

    # Use separate history file.
    my $history_file = "$ENV{HOME}/.runtime_debugger_testmode.info";
    unlink $history_file if -e $history_file;
    $repl->{history_file} = $history_file;
    $repl->_restore_history();

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

    my $completion_return;
    $repl->attr->{attempted_completion_function} = sub {
        my ( $text, $line, $start, $end ) = @_;
        my @ret = $repl->_complete( @_ );
        $completion_return = \@ret;
        @ret;
    };

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
            stdin      => $stdin,
            completion => $completion_return,
            step       => $step_return,
            eval       => $eval_return,
            stdout     => $stdout,
        };
    };
}

=head1 Sample test case
    
    # This should be enough data to test the module.
    {
        name             => 'STRING',
        input            => 'STRING',
        expected_results => {
            stdin        => 'STRING', # Input.
            completion   => ARRAYREF, # Result of tab completion (empy if no TAB).
            step         => 'STRING', # After "_step".
            eval         => 'STRING', # After "eval _step"
            stdout       => 'STRING', # Result of print.
        },
    },

=cut

my @cases = (

    # Literal.
    {
        name             => 'simple line 1',
        input            => 'abc',
        expected_results => {
            step => 'abc',
        }
    },
    {
        name             => 'simple line 2',
        input            => 'abc2',
        expected_results => {
            step => 'abc2',
        }
    },

    # # Empty.
    # {
    #     name            => 'Empty',
    #     input           => '',
    #     expected_line   => '',
    #     expected_output => '',
    # },
    # {
    #     name            => 'Empty TAB completion',
    #     input           => "$TAB",
    #     expected_line   => '$str1 $str2',
    #     expected_output => '',
    # },

    # # Help.
    # {
    #     name            => 'Help',
    #     input           => 'h',
    #     expected_line   => '',
    #     expected_output => '',
    #     # Remove color.
    #     # Normalize version.
    # },

    # # History.
    # {
    #     name            => 'History - default lines',
    #     input           => 'hist',
    #     expected_line   => '',
    #     expected_output => '',
    # },
    # {
    #     name            => 'History - 10 lines',
    #     input           => 'hist 10',
    #     expected_line   => '',
    #     expected_output => '',
    # },

    # # Print.
    # {
    #     name            => 'Print literal',
    #     input           => 'p 123',
    #     expected_line   => 'p 123',
    #     expected_output => '123',
    # },
    # {
    #     name            => 'Print TAB complete: p',
    #     input           => "p$TAB",
    #     expected_line   => 'p $coderef  $obj      $repl     $str1     $str2',
    #     expected_output => 'p',
    # },

    # {
    #     name            => 'Print TAB complete: p $ ',
    #     input           => 'p "$n' . $TAB . '123"',
    #     expected_line   => '',
    #     expected_output => '',
    # },

    # {
    #     name            => 'Print TAB complete: p $ ',
    #     input           => "p \$$TAB",
    #     expected_line   => 'p $coderef  $obj      $repl     $str1     $str2',
    #     expected_output => 'p $',
    # },
);

# Signals that a new character can be read from readline.
my $ready_to_read = 0;
$repl->attr->{input_available_hook} = sub { $ready_to_read };

for my $case ( @cases ) {

    # $ready_to_read = 1;
    my $results_all      = $RUN->( $case->{input} );
    my $expected_results = $case->{expected_results};
    my @keys             = keys %$expected_results;
    my %results;
    @results{@keys} = @$results_all{@keys};

    # p \%results, "--maxdepth=0";

    is_deeply \%results, $expected_results, $case->{name};
}

$repl->_exit( "test" );

done_testing();
