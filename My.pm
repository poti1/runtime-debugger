package My;

use strict;
use warnings;

my $var = 456;

use Runtime::Debugger -nofilter;

# use Runtime::Debugger;
# HERE1

print "111A\n";

# HERE2
print "111B\n";

#TODO: Remove this debug code !!!
use feature    qw(say);
use Mojo::Util qw(dumper);

# say run;
eval run;

$var = 789;

# HERE2
print "more\n";

