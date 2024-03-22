#!/usr/bin/env perl

# Can print $v only once!!!
# Second call returns undef.
# Some coderef optimization???
# Lexical variable goes undef on second call.


{
    package RD;

    use strict;
    use warnings;
    use Scalar::Util qw( reftype );
    use PadWalker qw( peek_our peek_my );
    use e;

    sub _init {
        my ($class,$scope) = @_;

        my $self = bless {}, $class;

        if (not defined $scope) {
            $scope = $self->_calc_scope;
        }

        my %vars = (
            peek_our($scope)->%*,
            peek_my($scope)->%*,
        );

        $self->{vars} = \%vars;

        $self;
    }

    sub _calc_scope {
        my ($self) = @_;

        my $scope = 0;
        my $pkg   = __PACKAGE__;
        my $caller;

        # Find the first scope level outside
        # this package.
        1 while (
            ($caller = caller(++$scope)),
            $caller and $caller eq $pkg
        );
        say "scope: $scope";

        $scope;
    }

    sub repl {
        my ($class,$scope) = @_;

        my $self = $class->_init($scope);

        # Scalars
      # $self->_apply_peeks('say $s');

      # $self->_apply_peeks('say $ar');
      # $self->_apply_peeks('say $ar->[1]');
      # $self->_apply_peeks('say $ar->[1] = 42');

      # $self->_apply_peeks('say $hr');
      # $self->_apply_peeks('say $hr->{b}');
      # $self->_apply_peeks('$hr->{b} = 3');
    
      # $self->_apply_peeks('say $o->{cat} = 123');
      # $self->_apply_peeks('say $o->{cat}');
      # $self->_apply_peeks('say $o->get');

        # Array
      # $self->_apply_peeks('say @a');
      # $self->_apply_peeks('say "@a"');
      # $self->_apply_peeks('say $a[1]');
      # $self->_apply_peeks('say $a[1] = 33');
      # $self->_apply_peeks('say $h{b}');
      # $self->_apply_peeks('say $h{b} = 44');
      # $self->_apply_peeks('say @h{b} = 45');

        # Hash
        $self->_apply_peeks('say join " ", sort keys %h');
    }

    sub _apply_peeks {
        my ($self, $code) = @_;
    
        say "code:  [$code]";
    
        $code =~ s{
            (?<var>
                (?<sigil> [\$\@%] )
                (?<name> [_A-Za-z]\w* )
            )
            (?= (?<next> .{0,3} ) )
        }
        {
            my $var   = $+{var};
            my $sigil = $+{sigil};
            my $name  = $+{name};
            my $next  = $+{next}  // "";

            # Find the true variable with sigil.
            if ( $next =~ /\[/ ) { # Array ref.
                $var = "\@$name"; 
            }
            elsif ( $next =~ /\{/ ) { # Hash ref.
                $var = "\%$name"; 
            }

            my $ref = ref $self->{vars}{$var};
            my $val = "\$self->{vars}{qq(\Q$var\E)}";
    
          # say "var:   $var";
          # say "sigil: $sigil";
          # say "next:  $next";
          # say "ref:   $ref";

            if ($ref eq 'REF') {
                $val = "\${$val}";
            }
            elsif ($ref eq 'ARRAY') {
                $val = "\@{$val}";
            }
            elsif ($ref eq 'HASH') {
                $val = "\%{$val}";
            }
            else {
                die "Unsupported type '$ref' (should not be here!!!)\n";
            }
    
            $val;
        }xge;
    
        say "code:  [$code]";
    
        eval $code;
        die $@ if $@;
    }
}

use strict;
use warnings;
use e;

my $v1  = 111;

{
    package A;
    sub get { "got method" }
}

sub {
    my $s  = 777;
    my $ar = [ 1, 2 ];
    my $hr = { a => 1, b => 2 };
    my %h  = ( a => 1, b => 2 );
    my @a  = ( 1, 2 );
    my $o  = bless{ cat => 5 }, "A";

    RD->repl;

  # p $s;
  # p $ar;
  # p $hr;
  # p $o;

  # p @a;

    p %h;

}->();

1;

