#!/bin/env perl

use 5.006;
use strict;
use warnings;
use Module::Build;
Module::Build->VERSION( '0.4004' );

my $class = Module::Build->subclass(
    code => q{
        sub ACTION_install {
            my ($s) = @_;
            $s->_clear_cache;
            $s->_check_for_source_command if os_type eq "Unix";
            $s->SUPER::ACTION_install;
        }
    },
);

my $builder = $class->new(
    module_name        => 'Runtime::Debugger',
    license            => 'artistic_2',
    dist_author        => q{Tim Potapov <tim.potapov[AT]gmail.com>},
    dist_version_from  => 'lib/Runtime/Debugger.pm',
    release_status     => 'stable',
    configure_requires => {
        'Module::Build' => '0.4004',
    },
    test_requires => {
        'Test::More' => '0',
    },
    requires => {
        'perl'                => '5.012',
        'Term::ReadLine::Gnu' => '1.44',
        'PadWalker'           => '2.5',
        'Class::Tiny'         => '1.008',
        'Module::Functions'   => '2.1.3',
    },
    add_to_cleanup => [ 'Runtime-Debugger-*', 'build_dir/', 'MANIFEST*.bak' ],
    meta_merge     => {
        resources => {
            bugtracker => 'https://github.com/poti1/runtime-debugger/issues',
            repository => 'https://github.com/poti1/runtime-debugger',
        },
    },
);

$builder->create_build_script();
