#!/usr/bin/env perl

use Mojo::File qw(path);

eval path(glob '03*')->slurp;
