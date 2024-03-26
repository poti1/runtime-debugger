#!/usr/bin/env perl

use Mojo::File qw(path);

eval path(glob '05*')->slurp;
