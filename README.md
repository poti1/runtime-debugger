# LOGO

     ____              _   _
    |  _ \ _   _ _ __ | |_(_)_ __ ___   ___
    | |_) | | | | '_ \| __| | '_ ` _ \ / _ \
    |  _ <| |_| | | | | |_| | | | | | |  __/
    |_| \_\\__,_|_| |_|\__|_|_| |_| |_|\___|

     ____       _
    |  _ \  ___| |__  _   _  __ _  __ _  ___ _ __
    | | | |/ _ \ '_ \| | | |/ _` |/ _` |/ _ \ '__|
    | |_| |  __/ |_) | |_| | (_| | (_| |  __/ |
    |____/ \___|_.__/ \__,_|\__, |\__, |\___|_|
                            |___/ |___/

# NAME

Runtime::Debugger - Easy to use REPL with existing lexical support and DWIM tab completion.

(emphasis on "existing" since I have not yet found this support in other modules).

# SYNOPSIS

In a script:

    use Runtime::Debugger;
    repl;

On the commandline):

    perl -MRuntime::Debugger -E 'repl'

Same, but with some variables to play with:

    perl -MRuntime::Debugger -E 'my $str1 = "Func"; our $str2 = "Func2"; my @arr1 = "arr-1"; our @arr2 = "arr-2"; my %hash1 = qw(hash 1); our %hash2 = qw(hash 2); my $coderef = sub { "code-ref: @_" }; {package My; sub Func{"My-Func"} sub Func2{"My-Func2"}} my $obj = bless {}, "My"; repl; say $@'

Test command:

    RUNTIME_DEBUGGER_DEBUG=2 perl -Ilib/ -MRuntime::Debugger -E 'my @a = 1..2; my %h = qw( a 11 b 22 ); my $v = 222; my $o = bless {a => 11}, "A"; my $ar = \@a; my $hr = \%h; use warnings FATAL => "all"; eval{ say qr<$hr-\>{b}> }; say "222"'

# DESCRIPTION

"What? Another debugger? What about ... ?"

## Other Modules

### perl5db.pl

The standard perl debugger (`perl5db.pl`) is a powerful tool.

Using `per5db.pl`, one would normally be able to do this:

    # Insert a breakpoint in your code:
    $DB::single = 1;

    # Then run the perl debugger to navigate there quickly:
    PERLDBOPT='Nonstop' perl -d my_script

If that works for you, then dont' bother with this module!
(joke. still try it.)

### Devel::REPL

This is a great and extendable module!

Unfortunately, I did not find a way to get the lexical variables
in a scope. (maybe I missed a plugin?!)

Example:

    perl -MDevel::REPL -E '
        my  $my_var  = 111;                # I want to access this
        our $our_var = 222;                # and this.
        my $repl = Devel::REPL->new;
        $repl->load_plugin($_) for qw(
            History
            LexEnv
            DDS
            Colors
            Completion
            CompletionDriver::INC
            CompletionDriver::LexEnv
            CompletionDriver::Keywords
            CompletionDriver::Methods
        );
        $repl->run;
    '

Sample Output:

    $ print $my_var
    Compile error: Global symbol "$my_var" requires explicit package name ...

    $ print $our_var
    Compile error: Global symbol "$our_var" requires explicit package name ...

### Reply

This module also looked nice, but same issue.

Example:

    perl -MReply -E '
        my $var=111;
        Reply->new->run;
    '

Sample Output:

    > print $var
    1
    > my $var2 = 222
    222
    > print $var2
    1

## Genesis

While debugging some long-running, perl,
Selenium test files, I basically got bored
and created a simple Read Evaluate Print Loop
(REPL). Originally I would have a hot key
command to drop in a snippet of code like
this into my test code to essentially insert a breakpoint/pause.

One can then examine what's going on in that
area of code and evaluate some code.

Originally the repl code snippet was something
as simple as this:

    while(1){
      my $in = <STDIN>;
      chomp $in;
      last if $in eq 'q';
      eval $in;
    }

With that small snippet I could pause in a long
running test (which I didn't write) and try out
commands to help me to understand what needs to
be updated in the test (like a ->click into a
field before text could be entered).

And I was quite satisfied.

From there, this module increased in features
such as using `Term::ReadLine` for a more
natural readline support, tab completion,
and history (up arrow).

## Attempted Solutions

This module has changed in its approach quite a
few times since it turns out to be quite tricky
to perform `eval_in_scope`.

### Source Filter

To make usage of this module as simple as
possible, I tried my hand at source filters.

My idea was that by simply adding this line of code:

    use Runtime::Debugger;

That would use a source filter to add in the REPL code.

This solution was great, but source filters can only
be applied at COMPILE TIME (That was new to me as well).

Unfortunately, the tests I am dealing with are
read as a string then evaled.

So, source filters, despite how clean they would
make my solution, would not work for my use cases.

### Back To Eval

Then I decided to go back to using a command like:

    use Runtime::Debugger;
    eval run;

Where run would basically generates the REPL
code and eval would use the current scope to
apply the code.

Side note: other Debuggers I had tried before this
one could not update lexical variables in the
current scope. So this, I think, is unique in this debugger.

#### Next pitfall

I learned later that `eval run` would under
certain circumstances not work:

First call would print 111, while the exact
same eval line would print undef afterwards.

    sub {
        my $v = 111;
        eval q(
            # my $v = $v; # Kind of a fix.
            eval 'say $v'; # 111
            eval 'say $v'; # undef
        );
    }->();

#### Still can eval run

Using `eval run` is still possible (for now).

Just be aware that it does not evaluate correctly
under certaini circumstances.

## Current Solution

Simply add these lines:

    use Runtime::Debugger;
    repl;

This will basically insert a read, evaluate,
print loop (REPL).

This should work for more cases (just try not
to use nasty perl magic).

### Goal

To reach the current solution, it was essential
to go back to the main goal.

And the goal/idea is simple, be able to evaluate
an expression in a specific scope/context.

Basically looking for something like:

    peek_my(SCOPE)

But instead for eval:

    eval_in_scope(SCOPE)

Given `eval_in_scope(1)`, that would evaluate an expression,
but in a scope/context one level higher.

### Implementation

#### Scope

In order to eval a string of perl code correctly,
we need to figure out at which level the variable
is located.

#### Peek

Given the scope level, peek\_my/our is utilized
to grab all the variables.

#### Preprocess

Then we need to preprocess the piece of perl code
that would be evaled.

At this stage variables would be replaced which
their equivalent representation at found in
peek\_my/our.

#### Eval

Finally, eval the string.

### Future Ideas

One idea would be to create an XS function
which can perform an eval in specific scope,
but naturally without the translation magic
that is currently being done.

This might appear like peek\_my, but for eval.
So something like this:

    eval_in_scope("STRING_TO_EVAL", SCOPE_LEVEL);

# FUNCTIONS

## run

Runs the REPL (dont forget eval!)

    eval run

Sets `$@` to the exit reason like 'INT' (Control-C) or 'q' (Normal exit/quit).

Do NOT use this unless for oneliners (which do not support source filters).

Note: This method is more stable than repl(), but at the same
time has limits. [See also](#lossy-undef-variable)

## repl

Works like eval, but without [the lossy bug](#lossy-undef-variable)

## \_apply\_peeks

Transform variables in a code string
into references to the same variable
as found with peek\_my/our.

Try to insert the peek\_my/our references
(peeks) only when needed (should appear
natural to the user).

Should NOT transform this:

    say "%h"

Instead, this:

    say "@a"

Might be transformed into:

    say "@{$repl->{peeks_all}{'@a'}}";

## Tab Completion

This module has rich, DWIM tab completion support:

    - Press TAB with no input to view commands and available variables in the current scope.
    - Press TAB after an arrow ("->") to auto append either a "{" or "[" or "(".
       This depends on the type of variable before it.
    - Press TAB after a hash (or hash object) to list available keys.
    - Press TAB anywhere else to list variables.

## \_match

Returns the possible matches:

Input:

    words   => ARRAYREF, # What to look for.
    partial => STRING,   # Default: ""  - What you typed so far.
    prepend => "STRING", # Default: ""  - prepend to each possiblity.
    nospace => 0,        # Default: "0" - will not append a space after a completion.

## help

Show help section.

## History

All commands run in the debugger are saved locally and loaded next time the module is loaded.

## hist

Can use hist to show a history of commands.

By default will show 20 commands:

    hist

Same thing:

    hist 20

Can show more:

    hist 50

## d

You can use "d" as a print command which can show a simple or complex data structure.

Data::Dumper::Dump anything.

    d 123
    d [1, 2, 3]

## Data::Printer

You can use "p" as a print command which
can show a simple or complex data structure
with colors.

Some example uses:

    p 123
    p [1, 2, 3]
    p $scalar
    p \@array
    p \%hash
    p $object

## uniq

Returns a unique list of elements.

List::Util in at least perl v5.16 does not
provide a unique function.

## Internal Properties

### attr

Internal use.

### debug

Internal use.

### term

Internal use.

# ENVIRONMENT

Install required library:

    sudo apt install libreadline-dev

Enable this environmental variable to show debugging information:

    RUNTIME_DEBUGGER_DEBUG=1

# SEE ALSO

## [https://perldoc.perl.org/perldebug](https://perldoc.perl.org/perldebug)

[Why not perl debugger?](#perl5db-pl)

## [https://metacpan.org/pod/Devel::REPL](https://metacpan.org/pod/Devel::REPL)

[Why not Devel::REPL?](#devel-repl)

## [https://metacpan.org/pod/Reply](https://metacpan.org/pod/Reply)

[Why not Reply?](#reply)

# AUTHOR

Tim Potapov, `<tim.potapov[AT]gmail.com>` 🐪🥷

# BUGS

## Control-C

Doing a Control-C may occassionally break the output in your terminal.

Simply run any one of these:

    reset
    tset
    stty echo

## New Variables

Currently it is not possible to create new lexicals (my) variables.

I have not yet found a way to run "eval" with a higher scope of lexicals.
(perhaps there is another way?)

You can make global variables though if:

    - By default ($var=123)
    - Using our (our $var=123)
    - Given the full path ($My::var = 123)

## Lossy undef Variable

inside a long running (and perhaps complicated) script, a variable
may become undef.

This piece of code demonstrates the problem with using c&lt;eval run>.

    sub Func {
        my ($code) = @_;
        $code->();
    }

    Func( sub{
        my $v2 = 222;

        # This causes issues.
        use Runtime::Debugger -nofilter;
        eval run;

        # Whereas, this one uses a source filter and works.
        use Runtime::Debugger;
    });

This issue is described here [https://www.perlmonks.org/?node\_id=11158351](https://www.perlmonks.org/?node_id=11158351)

## Other

Please report any (other) bugs or feature requests to [https://github.com/poti1/runtime-debugger/issues](https://github.com/poti1/runtime-debugger/issues).

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Runtime::Debugger

You can also look for information at:

[https://metacpan.org/pod/Runtime::Debugger](https://metacpan.org/pod/Runtime::Debugger)
[https://github.com/poti1/runtime-debugger](https://github.com/poti1/runtime-debugger)

# LICENSE AND COPYRIGHT

This software is Copyright (c) 2022 by Tim Potapov.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
