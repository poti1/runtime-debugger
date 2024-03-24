#!/usr/bin/env perl

use Mojo::File qw(path);

eval path(glob '02*')->slurp;
