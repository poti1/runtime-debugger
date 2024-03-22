#!perl

package MyTest;

use 5.006;
use strict;
use warnings;
use Test::More tests => 73;
use Runtime::Debugger;
use e;

# Can enable for more outout when debugging.
$ENV{RUNTIME_DEBUGGER_DEBUG} = 0;

{
    package A;
    sub get { "got method" }
}

sub run_suite {
    $Term::ReadLine::Gnu::has_been_initialized = 0;

    my $s  = 777;
    my $ar = [ 1, 2 ];
    my $hr = { a => 1, b => 2 };
    my %h  = ( a => 1, b => 2 );
    my @a  = ( 1, 2 );
    my $o  = bless{ cat => 5 }, "A";

    my $repl = Runtime::Debugger->_init;

    my @cases = (
   
        # Scalar.
        {
            name  => "Print scalar",
            input => 'p $s',
            expected => {
                apply_peeks => 'p ${$repl->{peek_all}{qq(\$s)}}',
                vars_after    => sub {
                    is $s, 777, shift;
                },
            },
        },
        {
            name  => "Get scalar",
            input => '$s',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$s)}}',
                eval_result => 777,
                vars_after    => sub {
                    is $s, 777, shift;
                },
            },
        },
        {
            name  => "Set scalar",
            input => '$s = 555',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$s)}} = 555',
                eval_result => 555,
                vars_after    => sub {
                    is $s, 555, shift;
                },
            },
        },
        {
            name  => "Get scalar again",
            input => '$s',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$s)}}',
                eval_result => 555,
                vars_after  => sub {
                    is $s, 555, shift;
                },
            },
            cleanup => sub {
                $s = 777;
            },
        },

        # Array reference.
        {
            name  => "Print array reference",
            input => 'p $ar->[1]',
            expected => {
                apply_peeks => 'p ${$repl->{peek_all}{qq(\$ar)}}->[1]',
                vars_after  => sub {
                    is_deeply $ar, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Get array reference",
            input => '$ar->[1]',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$ar)}}->[1]',
                eval_result => 2,
                vars_after  => sub {
                    is_deeply $ar, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Set array reference",
            input => '$ar->[1] = "my_ar_1"',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$ar)}}->[1] = "my_ar_1"',
                eval_result => "my_ar_1",
                vars_after  => sub {
                    is_deeply $ar, [ 1, 'my_ar_1' ], shift;
                },
            },
        },
        {
            name  => "Get array reference again",
            input => '$ar->[1]',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$ar)}}->[1]',
                eval_result => "my_ar_1",
                vars_after  => sub {
                    is_deeply $ar, [ 1, 'my_ar_1' ], shift;
                },
            },
            cleanup => sub {
                $ar->[1] = 2;
            },
        },

        # Hash reference.
        {
            name  => "Print hash reference",
            input => 'p $hr->{b}',
            expected => {
                apply_peeks => 'p ${$repl->{peek_all}{qq(\$hr)}}->{b}',
                vars_after  => sub {
                    is_deeply $hr, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Get hash reference",
            input => '$hr->{b}',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$hr)}}->{b}',
                eval_result => 2,
                vars_after  => sub {
                    is_deeply $hr, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Set hash reference",
            input => '$hr->{b} = "my_hr_b"',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$hr)}}->{b} = "my_hr_b"',
                eval_result => "my_hr_b",
                vars_after  => sub {
                    is_deeply $hr, { a => 1, b => 'my_hr_b' }, shift;
                },
            },
        },
        {
            name  => "Get hash reference again",
            input => '$hr->{b}',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$hr)}}->{b}',
                eval_result => "my_hr_b",
                vars_after  => sub {
                    is_deeply $hr, { a => 1, b => 'my_hr_b' }, shift;
                },
            },
            cleanup => sub {
                $hr->{b} = 2;
            },
        },

        # Object.
        {
            name  => "Print object",
            input => 'p $o->{cat}',
            expected => {
                apply_peeks => 'p ${$repl->{peek_all}{qq(\$o)}}->{cat}',
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Get object",
            input => '$o->{cat}',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$o)}}->{cat}',
                eval_result => 5,
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Set object",
            input => '$o->{cat} = "my_o_cat"',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$o)}}->{cat} = "my_o_cat"',
                eval_result => "my_o_cat",
                vars_after  => sub {
                    is $o->{cat}, 'my_o_cat', shift;
                },
            },
        },
        {
            name  => "Get object again",
            input => '$o->{cat}',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$o)}}->{cat}',
                eval_result => "my_o_cat",
                vars_after  => sub {
                    is $o->{cat}, 'my_o_cat', shift;
                },
            },
            cleanup => sub {
                $o->{cat} = 5;
            },
        },
        {
            name  => "Print object method",
            input => 'p $o->get',
            expected => {
                apply_peeks => 'p ${$repl->{peek_all}{qq(\$o)}}->get',
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Print object method (paren)",
            input => 'p $o->get()',
            expected => {
                apply_peeks => 'p ${$repl->{peek_all}{qq(\$o)}}->get()',
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Get object method",
            input => '$o->get',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$o)}}->get',
                eval_result => "got method",
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Get object method (paren)",
            input => '$o->get()',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\$o)}}->get()',
                eval_result => "got method",
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },

        # Array.
        {
            name  => "Print array element",
            input => 'p $a[1]',
            expected => {
                apply_peeks => 'p ${$repl->{peek_all}{qq(\@a)}}[1]',
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Get array element",
            input => '$a[1]',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\@a)}}[1]',
                eval_result => 2,
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Set array element",
            input => '$a[1] = "my_a_1"',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\@a)}}[1] = "my_a_1"',
                eval_result => "my_a_1",
                vars_after  => sub {
                    is_deeply \@a, [ 1, 'my_a_1' ], shift;
                },
            },
        },
        {
            name  => "Get array element again",
            input => '$a[1]',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\@a)}}[1]',
                eval_result => "my_a_1",
                vars_after  => sub {
                    is_deeply \@a, [ 1, 'my_a_1' ], shift;
                },
            },
            cleanup => sub {
                $a[1] = 2;
            },
        },
        {
            name  => "Print array",
            input => 'p @a',
            expected => {
                apply_peeks => 'p @{$repl->{peek_all}{qq(\@a)}}',
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Join array",
            input => 'join " ", @a',
            expected => {
                apply_peeks => 'join " ", @{$repl->{peek_all}{qq(\@a)}}',
                eval_result => "1 2",
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },

        # Hash.
        {
            name  => "Print hash element",
            input => 'p $h{b}',
            expected => {
                apply_peeks => 'p ${$repl->{peek_all}{qq(\%h)}}{b}',
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Get hash element",
            input => '$h{b}',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\%h)}}{b}',
                eval_result => 2,
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Set hash element",
            input => '$h{b} = "my_h_b"',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\%h)}}{b} = "my_h_b"',
                eval_result => "my_h_b",
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 'my_h_b' }, shift;
                },
            },
        },
        {
            name  => "Get hash element again",
            input => '$h{b}',
            expected => {
                apply_peeks => '${$repl->{peek_all}{qq(\%h)}}{b}',
                eval_result => "my_h_b",
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 'my_h_b' }, shift;
                },
            },
            cleanup => sub {
                $h{b} = 2;
            },
        },
        {
            name  => "Get hash",
            input => 'say for sort keys %h',
            expected => {
                apply_peeks => 'say for sort keys %{$repl->{peek_all}{qq(\%h)}}',
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Join hash key",
            input => 'join " ", sort keys %h',
            expected => {
                apply_peeks => 'join " ", sort keys %{$repl->{peek_all}{qq(\%h)}}',
                eval_result => "a b",
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },

        # TODO

        # Nested structures.

        # Quoted: "
        {
            name  => "Double quoted scalar",
            input => '"$s"',
            expected => {
                apply_peeks => '"${$repl->{peek_all}{qq(\$s)}}"',
                eval_result => "777",
                vars_after    => sub {
                    is $s, 777, shift;
                },
            },
        },
        {
            name  => "Double quoted array ref",
            input => '"$ar->[1]"',
            expected => {
                apply_peeks => '"${$repl->{peek_all}{qq(\$ar)}}->[1]"',
                eval_result => "2",
                vars_after  => sub {
                    is_deeply $ar, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Double quoted hash ref",
            input => '"$hr->{b}"',
            expected => {
                apply_peeks => '"${$repl->{peek_all}{qq(\$hr)}}->{b}"',
                eval_result => 2,
                vars_after  => sub {
                    is_deeply $hr, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Double quoted object key",
            input => '"$o->{cat}"',
            expected => {
                apply_peeks => '"${$repl->{peek_all}{qq(\$o)}}->{cat}"',
                eval_result => 5,
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Double quoted object method",
            input => '"$o->get"',
            expected => {
                apply_peeks => '"${$repl->{peek_all}{qq(\$o)}}->get"',
                eval_result => qr{ A=HASH \( 0x\w+ \) ->get }x,
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Double quoted scalar with fake method",
            input => '"$s->get"',
            expected => {
                apply_peeks => '"${$repl->{peek_all}{qq(\$s)}}->get"',
                eval_result => "777->get",
                vars_after  => sub {
                    is $s, 777, shift;
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Double quoted array",
            input => '"@a"',
            expected => {
                apply_peeks => '"@{$repl->{peek_all}{qq(\@a)}}"',
                eval_result => "1 2",
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Double quotes array element",
            input => '"$a[1]"',
            expected => {
                apply_peeks => '"${$repl->{peek_all}{qq(\@a)}}[1]"',
                eval_result => "2",
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Double quotes array elements",
            input => 'say "@a[1,2]"',
            expected => {
                apply_peeks => 'say "@{$repl->{peek_all}{qq(\@a)}}[1,2]"',
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Double quoted hash",
            input => '"%h"',
            expected => {
                apply_peeks => '"%h"',
                eval_result => "%h",
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Double quoted hash key",
            input => '"$h{b}"',
            expected => {
                apply_peeks => '"${$repl->{peek_all}{qq(\%h)}}{b}"',
                eval_result => "2",
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Double quoted hash keys",
            input => '"@h{qw( a b )}"',
            expected => {
                apply_peeks => '"@{$repl->{peek_all}{qq(\%h)}}{qw( a b )}"',
                eval_result => "1 2",
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },

        # Quoted: '
        {
            name  => "Single quoted scalar",
            input => q('$s'),
            expected => {
                apply_peeks => q('$s'),
                eval_result => q($s),
                vars_after    => sub {
                    is $s, 777, shift;
                },
            },
        },
        {
            name  => "Single quoted array ref",
            input => q('$ar->[1]'),
            expected => {
                apply_peeks => q('$ar->[1]'),
                eval_result => q($ar->[1]),
                vars_after  => sub {
                    is_deeply $ar, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Single quoted hash ref",
            input => q('$hr->{b}'),
            expected => {
                apply_peeks => q('$hr->{b}'),
                eval_result => q($hr->{b}),
                vars_after  => sub {
                    is_deeply $hr, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Single quoted object key",
            input => q('$o->{cat}'),
            expected => {
                apply_peeks => q('$o->{cat}'),
                eval_result => q($o->{cat}),
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Single quoted object method",
            input => q('$o->get'),
            expected => {
                apply_peeks => q('$o->get'),
                eval_result => q($o->get),
                vars_after  => sub {
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Single quoted scalar with fake method",
            input => q('$s->get'),
            expected => {
                apply_peeks => q('$s->get'),
                eval_result => q($s->get),
                vars_after  => sub {
                    is $s, 777, shift;
                    is $o->{cat}, 5, shift;
                },
            },
        },
        {
            name  => "Single quoted array",
            input => q('@a'),
            expected => {
                apply_peeks => q('@a'),
                eval_result => q(@a),
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Single quotes array element",
            input => q('$a[1]'),
            expected => {
                apply_peeks => q('$a[1]'),
                eval_result => q($a[1]),
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Single quotes array elements",
            input => q('@a[1,2]'),
            expected => {
                apply_peeks => q('@a[1,2]'),
                eval_result => q(@a[1,2]),
                vars_after  => sub {
                    is_deeply \@a, [ 1, 2 ], shift;
                },
            },
        },
        {
            name  => "Single quoted hash",
            input => q('%h'),
            expected => {
                apply_peeks => q('%h'),
                eval_result => q(%h),
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Single quoted hash key",
            input => q('$h{b}'),
            expected => {
                apply_peeks => q('$h{b}'),
                eval_result => q($h{b}),
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },
        {
            name  => "Single quoted hash keys",
            input => q('@h{qw( a b )}'),
            expected => {
                apply_peeks => q('@h{qw( a b )}'),
                eval_result => q(@h{qw( a b )}),
                vars_after  => sub {
                    is_deeply \%h, { a => 1, b => 2 }, shift;
                },
            },
        },


        # Quoted: qq

        # Quoted: q

        # Quoted: qr

        # Quoted: qw

        # Quoted: Mixed

    );
   
    for my $case ( @cases ) {
        pass("--- $case->{name} ---");

        # Check if peek data is properly applied.
        my $applied = $repl->_apply_peeks($case->{input});
        last unless is(
            $applied,
            $case->{expected}{apply_peeks},
            "$case->{name} - apply peeks",
        );

        # Check result of eval.
        if ( $case->{expected}{eval_result} ) {
            my $expected = $case->{expected}{eval_result};
            my $actual   = eval $applied;
            if ( ref($expected) eq ref(qr//) ){
                last unless like(
                    $actual,
                    $expected,
                    "$case->{name} - eval result (regex)",
                );
            }
            else {
                last unless is(
                    $actual,
                    $expected,
                    "$case->{name} - eval result",
                );
            }
        }

        # Check variables are actually set.
        if ( $case->{expected}{vars_after} ) {
            last unless $case->{expected}{vars_after}->(
                "$case->{name} - vars after"
            );
        }

        # Cleanup/reset variables.
        if ( $case->{cleanup} ) {
            $case->{cleanup}->();
        }
    }
}

sub title {
    my ($scenario) = @_;
    pass("--- --- $scenario --- ---");
}

################################
# Run under different scenarios.
################################

{
    title "Statement";
    run_suite();
}

sub Func {
    title "Function";
    run_suite();
}
Func();

sub {
    say "";
    title "Code Reference";
    run_suite();
}->();


