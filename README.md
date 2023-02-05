# NAME

Template::Perlish - Yet Another Templating system for Perl

# VERSION

This document describes Template::Perlish version 1.58.

# SYNOPSIS

    use Template::Perlish;

    my $tp = Template::Perlish->new();

    # A complex template, including some logic as Perl code
    my $tmpl = <<END_OF_TEMPLATE
    Dear [% name %],

       we are pleased to present you the following items:
    [%
       my $items = $variables{items}; # Available %variables
       my $counter = 0;
       for my $item (@$items) {
    %]
       [%= ++$counter %]. [% $item %]
    [%
       }
    %]

    Please consult our complete catalog at [% uris.2.catalog %].

    Yours,

       [% director.name %] [% director.surname %].
    END_OF_TEMPLATE

    my $processed = $tt->process($template, {
       name => 'Ciccio Riccio',
       items => [ qw< ciao a tutti quanti > ],
       uris => [
          'http://whatever/',
          undef,
          {
             catalog => 'http://whateeeeever/',
          }
       ],
       director => { surname => 'Poletti' },
    });

The above prints:

    Dear Ciccio Riccio,

       we are pleased to present you the following items:

       1. ciao
       2. a
       3. tutti
       4. quanti

    Please consult our complete catalog at http://whateeeeever/.

    Yours,

          Poletti.

There is also a convenience function for one-shot templates:

    use Template::Perlish qw< render >;
    my $rendered = render($template, \%variables);

There are also two functions that expose the _path_ splitting
algorithm and the variable traversal, in case you need them:

    use Template::Perlish qw< crumble traverse >;
    my $array_ref = crumble("some.'-1'.'comp-lex'.path");
    # returns [ 'some', '-1', 'comp-lex', 'path' ]

    my $var;
    my $ref_to_value = traverse(\$var, "some.0.'comp-lex'.path");
    $$ref_to_value = 42; # note double sigil for indirection
    # now we have that $some_variable is equal to:
    # { some => [ { 'comp-lex' => { path => 42 } } ] }

# SHOULD YOU USE THIS?

You're probably looking at the tons and tons of templating systems
available around - should you use this?

This system is quite basic and useful for simple situations. Say you
have a bunch of templates in which you want to put some variables - then
it's ok. On top of this, say that you want to add some simple logic -
like a couple of IF's or iterating over an array - then it's ok again.
For everything more complicated you should probably look elsewhere.

As a summary:

- PRO
    - lightweight, a single-file module with minimal requirements that you can
    easily embed in your script;
    - simple approach to variable substitution, following
    [Template::Toolkit](https://metacpan.org/pod/Template%3A%3AToolkit) to cope with scalars, hashes and
    arrays;
- PRO/CON
    - Perl code to handle all logic. This can be regarded as a PRO if you're a
    Perl programmer, because you already know the syntax; this is probably
    (definitively?) a CON in all other cases;
- CON
    - you have to explicitly code everything that goes beyond simple variable
    stuffing into a template.
    - if you care about security, you MUST look elsewhere. There are _string_
    `eval`s inside Template::Perlish, so you must be 100% or more sure that
    you trust your templates. Don't trust them if you don't write them
    yourself, and even in that case be suspicious.

If you think that this module does not fit your requirements, my
personal suggestion for a templating system is
[Template::Toolkit](https://metacpan.org/pod/Template%3A%3AToolkit): it's complete, easy to use and
extensible, has excellent documentation (including a book and a quick
reference guide) and support. Do you need anything more?

But don't trust me! Take a look at _Choosing a Templating System_ at
[http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html](http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html),
where you can find a fairly complete comparison about the _streamline_
templating systems in Perl, and decide by yourself!

# DESCRIPTION

You bet, this is another templating system for Perl. Yes, because it's
the dream of every Perl programmer, me included. I needed something
that's easily portable, with no dependencies apart a recent Perl version
(but with some tweaking this should be solved), much in the spirit of
the ::Tiny modules.

Wherever possible I try to mimic Template::Toolkit, but I stop quite
early. If you only have to fill a template with a bunch of variables,
chances are that TT2 templates are good for Template::Perlish as well.
If you need even the slightest bit of logic, you'll have to part from
TT2 - and get full Perl power.

A template is simply a text (even if not necessarily) with some
particular markup to embed commands. In particular, all the stuff
included between `[%` and `%]` is considered as some sort of
_command_, and treated specially. All the rest is treated as simple
text. Of course, you can modify the start and stop delimiter for a
command.

_Commands_ can be of four different types:

- **variable embedding**

    that are expanded with the particular value for a given `variable`,
    where `variable`s are passed as a hash reference. A variable can be
    defined as a sequence of alphanumeric (actually `\w`) tokens, separated
    by dots (or anything described in ["Templates"](#templates) as of version 1.40). The
    variables hash is visited considering each token as a subkey, in order
    to let you visit complex data structures. You can also put arrays in,
    just use the index as a key in this case.

- **scalar Perl variable**

    that is expanded with the value of the given scalar variable;

- **Perl expression**

    this MUST have a `=` equal sign immediately after the opener, and
    contain a valid Perl expression. This expression is evaluated in scalar
    context and the result is printed;

- **code**

    good old Perl code, in order to provide you with control structures,
    modules, etc etc. This the most lazy approach I could think about, and
    it's also why this module is called `Perlish`.

Take a look at the example in the ["SYNOPSIS"](#synopsis), it actually contains all
that this module provides.

To start, you'll need a `Template::Perlish` object and, of course, a
template. Templates are provided as text strings; if you have them into
files, you are in charge of loading them first.

    # get a Template::Perlish object
    my $tp = Template::Perlish->new();

    # get the template (yes, it's your duty)
    my $tmpl = do { open my $fh, '<', 'filename'; local $/; <$fh> };

The basic operation mode is via the ["process"](#process) method, which works much
like in TT2. Anyway, this method will always give you back the generated
stuff, and won't print anything. This can probably be less memory
efficient when big templates are involved, but in this case you should
probably head somewhere else. Or not.

    # print out the template filled with some variables
    print $tp->process($tmpl, { key => 'value' });

Each template is transformed into Pure Perl code, then the code is
evaluated in order to get the output. Thus, if you want to operate on
the same template many times, a typical usage is:

    # compile the template with something like:
    my $compiled = $tp->compile($template);

    # use the compiled template multiple times with different data
    for my $dataset (@available_data) {
       print "DATASET\n", $tp->evaluate($compiled, $dataset), "\n\n";
    }

There is also a facility - namely ["compile\_as\_sub"](#compile_as_sub) - that returns an
anonymous sub that encapsulates the ["evaluate"](#evaluate) call above:

    my $sub = $tp->compile_as_sub($template)
       or die "template did not compile: $EVAL_ERROR";
    for my $dataset (@available_data) {
       print {*STDOUT} "DATASET\n", $sub->($dataset), "\n\n";
    }

As of release 1.2 the error reporting facility has been improved to
provide feedback if there are issues with the provided template, e.g.
when there is a syntax error in the Perl code inside. When an error
arises, the module will `die()` with a meaningful message about where
the error is. This happens with all the provided facilities.

Error checking is turned on automatically on all facilities. You can
avoid doing it in the ["compile"](#compile) method, although the check will kick
in at the first usage of the compiled form. To avoid the check upon the
compilation, pass the `no_check` option to ["compile"](#compile):

    my $compiled = $tp->compile($template, no_check => 1);

By default, the stuff is assumed to be utf-8 compliant, which is
reflected by option `utf8` defaulting to _true_ in ["**new**"](#new).
This default is inhibited by setting `utf8` to a false value, or
`binmode` to any defined value.

# INTERFACE 

## One Shot Templates

The following convenience function can be used to quickly render a
template:

- **render**

        use Template::Perlish qw< render >;
        my $rendered = render($template);              # OR
        my $rendered = render($template, %variables);  # OR
        my $rendered = render($template, $var_ref);    # OR
        my $rendered = render($template, $var_ref, $opts_ref);

    if you already have a template and the variables to fill it in, this is
    probably the quickest thing to do.

    You can pass the template alone, or you can pass the variables as well,
    either as a flat list (that will be converted back to a hash) or as a
    single reference.

    It's also possible to set all options described for constructor ["new"](#new), as long as you

    Returns the rendered template, i.e. the same output as ["process"](#process). Note
    that it assumes the default values for options explained in ["new"](#new).

## Constructor

- **new**

        $tp = Template::Perlish->new(@opts); # OR
        $tp = Template::Perlish->new(\%opts);

    constructor, does exactly what you think. You can provide any parameter,
    but only the following will make sense:

    - _binmode_

        string to set `binmode` on the output filehandle. A defined value
        disables the default to `utf8`.

    - _functions_

        (as of version 1.58) hash reference with functions that will be injected
        in the `Template::Perlish` namespace for the duration of the template
        evaluation. Keys are assumed to be valid function names, values are
        assumed to be valid sub references.

    - _method\_over\_keys_

        boolean flag used for traversal, see ["traverse"](#traverse).

        Defaults to _false_;

    - _start_

        delimiter for the start of a _command_ (as opposed to plain text/data).

        Defaults to `[%`;

    - _stdout_

        boolean value, allows one to _clobber_ `STDOUT` for collecting the
        expansion of a template, or to leave `STDOUT` untouched.

        New option as of release 1.52. Until the previous stable release, this
        behaviour was the norm: inside a template, whatever `print` to
        `STDOUT` is trapped and put in the template expansion. For this reason,
        this option defaults to a true value (`1`) in order to keep backwards
        compatibility.

        If you set this flag to a false value, `STDOUT` will not be modified
        and will be accessible from within the templates. In this case, if you
        still want to _print_ inside the template you can use function ["P"](#p).

        Defaults to _true_;

    - _stop_

        delimiter for the end of a _command_.

        Defaults to `%]`;

    - _strict\_blessed_

        boolean flag used for traversal, see ["traverse"](#traverse).

        Defaults to _false_;

    - _traverse\_methods_

        boolean flag used for traversal, see ["traverse"](#traverse).

        Defaults to _false_;

    - _utf8_

        sets the handling to utf8.

        Defaults to _true_, unless `binmode` option is set to a defined value.

    - _variables_

        variables that will be passed to all invocations of ["process"](#process) and/or
        ["evaluate"](#evaluate). It MUST be a reference to a hash.

        Defaults to an empty hash reference.

    - _-preset_

        this is a _meta_-option and is available only when the constructor is
        called with a list of key/value pairs, not with a hash reference.

        This allows you to load canned sequences of presets that will be exposed
        for different releases and allow you to quickly tune the usage of
        Template::Perlish, while still keeping backwards compatibility.

        Each preset is overlaid on the configuration as soon as it is
        encountered in the arguments list, so order matters. Here are the
        available presets:

        - `default`

            sets defaults values written above;

        - `1.52`

            overrides `stdout` to a _false_ value, while setting
            `traverse_method` and `method_over_key` to a _true_ one. As a matter
            of fact, it enables all new options available in release 1.52 in one
            single shot.

        As an example, if you want to use the new features in 1.52 but you would
        like keys in a hash to take precedence over methods, you can do either
        of the following:

            $o = Template::Perlish->new(
                -preset => '1.52',
                method_over_key => 0,
            );

            # OR

            $o = Template::Perlish->new(
                stdout => 1,
                traverse_methods => 0,
            );

    Parameters can be given directly as key-value pairs or via a hash
    reference. In the former case, you can provide the same option multiple
    times and also use meta-option `-preset` described above.

    By default, the delimiters are the same as TT2, i.e. `[%` and `%]`,
    and the variables hash is empty.

    The return value is a reference to an anonymous hash, whose elements are
    the ones described above. You can modify them at will, there are no
    accessors for this simple object.

## Template Handling

- **compile**

        $compiled = $tp->compile($template);
        $compiled = $tp->compile($template, no_check => $boolean);

    compile a template generating the relevant Perl code. Using this method
    is useful when the same template has to be used multiple times, so the
    compilation can be done one time only.

    You can turn off checking using the `no_check` optional parameter and
    passing a true value. The check will be performed upon the first usage
    of the compiled form though.

    Returns a hash containing, among the rest, a text version of the
    template transformed into Perl code.

- **compile\_as\_sub**

        $sub_reference = $tp->compile_as_sub($template);

    Much like ["compile"](#compile), this method does exactly the same compilation,
    but returns a reference to an anonymous subroutine that can be used each
    time you want to "explode" the template.

    The anonymous sub that is returned accepts a single, optional parameter,
    namely a reference with the same role as `$reference` in ["evaluate"](#evaluate).

    Note that if you add/change/remove values using the `variables` member
    of the Template::Perlish object, these changes will reflect on the
    anonymous sub, so you end up using different values in two subsequent
    invocations of the sub. This is consistent with the behaviuor of the
    ["evaluate"](#evaluate) method.

- **evaluate**

        $final_text = $tp->evaluate($compiled); # OR
        $final_text = $tp->evaluate($compiled, $reference);

    evaluate a template (in its compiled form, see ["compile"](#compile)) with the
    available variables. In the former form, only the already configured
    variables are used (see ["Constructor"](#constructor); in the latter, the given
    `$reference` is considered.

    If `$reference` is a hash reference, the variables set in the
    constructor (if any) are merged with the ones in `$reference` and
    eventually passed for expansion of the `$compiled` template. Keys from
    `$reference` override those from the constructor and they also end up
    in the `%variables` lexical hash that is visible in the template's
    scope.

    As of release 1.50, `$reference` can also be something else (most
    probably, an array reference), it is used as the variables entry point
    instead. In this case, the `%variables` lexical hash that is visible in
    the template's scope is shaped like this:

        %variables = (
           HASH => { variables from the constructor... },
           REF  => $reference,
        );

    so you have in any way the chance to access the variables set in the
    constructor.

    Returns the processed text as a string.

- **process**

        $final_text = $tp->process($template); # OR
        $final_text = $tp->process($template, $variables);

    this method included ["compile"](#compile) and ["evaluate"](#evaluate) into a single step.

## Templates

There's really very little to say: write your document/text/whatever,
and embed special parts with the delimiters of your choice (or stick to
the defaults). If you have to print stuff, just print to `STDOUT`, it
will be automatically catpured (unless you're calling the generated code
by yourself).

As of version 1.52, the new boolean option `stdout` has been
introduced, allowing to keep the old behaviour (i.e. printing to
`STDOUT` is captured in the expanded template) described above, or to
use the new one where `STDOUT` is not clobbered. This parameter
defaults to `1` (i.e. a _true_ value, in Perl sense) for backwards
compatibility. If you still want to _print_ out, though, you can use
the new function ["P"](#p). As a matter of fact, you're encouraged to always
use `P`, because it will work both in the old and in the new setup.

Anything inside these "special" parts matching the regular expression
`/^\s*\w+(?:\.\w+)*\s*$/`, i.e. consisting only of a sequence of
alphanumeric tokens separated by dots, are considered to be variables
and processed accordingly. Thus, available variables can be accessed in
two ways: using the dotted notation, as in

    [% some.value.3.lastkey %]

or explicitly using the `%variables` hash:

    [% print $variables{some}{value}[3]{lastkey} %]

The former is cleaner, but the latter is more powerful of course.

As of release 1.50, Template::Perlish does not assume that the input
data structure is a hash reference any more. Hence, `%variables` might
not actually contain your input; see ["Variables Accessors"](#variables-accessors) for a robust
way to get the right value instead. Or you can use `$V` if you feel
brave (it's a reference to either `%variables` or is whatever else was
provided as input, so it alwasy points to the _right_ data). See
["evaluate"](#evaluate) for additional information about the provided parameters
and `%variables`.

As of release 1.40, Template::Perlish also allows you to use more
complex variable names in your data structure and your template, without
having to resort to the second form. It will suffice to quote the
relevant parts where you want to put non-alphanumeric keys, e.g.:

    '$whatever'.'...'."with '\" quotes"

The quoting rules for this feature added in 1.40 are the following:

- **single quotes**

    are paired and can contain any character inside, except a single quote.
    Use double quotes if you need to put single quotes. The quotes
    themselves are stripped away before figuring out what the key is;

- **double quotes**

    are paired and can contain any character inside, with some care. If you
    need to put double quotes inside, you have to escape with a backslash.
    Also, if you want to insert a literal backslash, you have to prepend it
    with another backslash. In general, every time you put a backslash, the
    following character is taken as-is and the escaping backslash is tossed
    away. So the following:

        "\'\a\ \v\e\r\y\ \s\t\r\a\n\g\e\ \k\e\y\'"

    is interpreted as:

        'a very strange key'

    (including the single quotes).

- **the rest**

    must be alphanumeric only, like it was before.

If you happen to have a value you want to print inside a simple scalar
variable, instead of:

    [% print $variable; %]

you can also use the short form:

    [% $variable %]

Note: only the scalar variable name, nothing else apart optional spaces.
If you have something fancier, i.e. a Perl expression, you can use a
shortcut to evaluate it and print all in one single command:

    [%= my $value = 100; "*** $variable -> $value ***" %]

Note that there is an equal sign (`=`) immediately after the command
opener `[%`. The Perl expression is evaluated in scalar context, and
the result is printed (if defined, otherwise it's skipped). This sort of
makes the previous short form for simple scalars a bit outdated, but you
spare a character in any case and it's just DWIM.

If you know Perl, you should not have problems using the control
structures.  Just intersperse the code with the templates as you would
normally do in any other templating system:

    [%
       if ($variables{this}) {
    %]
         blah blah [% this %], foo bar!
    [%
       }
       else {
    %]
         yak yak that!
    [%
       }
    %]

Take care to always terminate your commands with a `;` each time you
would do it in actual code.

As of version 1.40, there are also a few functions that will make your
life easy if you want to access the variables, namely ["V"](#v) to access a
variable provided its dotted-path representation, ["A"](#a) for expanding
the variable as an array, ["H"](#h) to expand it as a hash, and ["HK"](#hk) and
["HV"](#hv) to get the keys and values of a hash, respectively.

There's no escaping mechanism, so if you want to include literal `[%`
or `%]` you either have to change delimiters, or you have to resort to
tricks. In particular, a stray closing inside a textual part won't be a
problem, e.g.:

    [% print "variable"; %] %] [% print "another"; %]

prints:

    variable %] another

The tricky part is including the closing in the Perl code, but there can
be many tricks:

    [% print '>>>%'.']<<<' %]

prints

    >>>%]<<<

To include a starter in the text just print it inside a Perl block:

    here it comes [%= '[%' %] the delimiter

prints:

    here it comes [% the delimiter

Another trick is to separate the two chars with an empty block:

    here it comes [[%%]% the delimiter

Including the starter in the Perl code is not a problem, of course.

So the bottom line is: who needs escaping?

## Variables Accessors

The following variable accessors can be used from within the templates.
All variable accessors accept three forms:

- without parameters. In this case, the root of the data is selected, then
the operation of the accessor is applied;
- with one parameter. In this case, the parameter is the path in the data
structure;
- with two parameters. In this case, the first parameter is the path in
the data structure, while the second one is the data structure to be
traversed.

The third alternative is useful when you want to take advantage of the
accessors on a sub-structure, like in the following example:

    # suppose $item is a hash of hashes at each iteration...
    for my $item (A 'some.array') {
       my $wanted = V 'data.inside.item', $item;
       # ... do something with $wanted...
    }

Here are the accessors:

- **A**

        A
        A 'path.to.arrayref'
        A 'path.to.arrayref', $root

    get the variable at the specific path and expand it as array. This can
    be useful if you want to iterate over a variable that you know is an
    array reference:

        [% for my $item (A 'my.array') { ... } %]

    is equivalent to:

        [% for my $item (@{$variables{my}{array}}) { ... } %]

    but more concise and a little more readable.

    When no path is passed, the root of the input data is assumed to be a
    reference to an array and that will be expanded.

    You can optionally pass a second parameter with a data structure. That
    will be used instead of the one provided to the template.

- **H**

        H
        H 'path.to.hashref'
        H 'path.to.hashref', $root

    get the variable at the specific path and expand it as hash.

    When no path is passed, the root of the input data is assumed to be a
    reference to a hash and that will be expanded.

    You can optionally pass a second parameter with a data structure. That
    will be used instead of the one provided to the template.

- **HK**

        HK
        HK 'path.to.hashref'
        HK 'path.to.hashref', $root

    get the variable at the specific path, expand it as hash and get its
    keys. This can be useful if you want to iterate over the keys of a
    variable that you know is an hash reference:

        [% for my $key (HK 'my.hash') { ... } %]

    is equivalent to:

        [% for my $key (keys %{$variables{my}{hash}}) { ... } %]

    but more concise and a bit more readable.

    When no path is passed, the root of the input data is assumed to be a
    reference to a hash and that will be expanded.

    You can optionally pass a second parameter with a data structure. That
    will be used instead of the one provided to the template.

- **HV**

        HV
        HV 'path.to.hashref'
        HV 'path.to.hashref', $root

    similar to ["HK"](#hk), but provides values instead of keys.

- **V**

        V
        V 'path.to.variable'
        V 'path.to.variable', $root

    get the variable at the specific path. The following:

        [%= V('path.to.variable') + 1 %]

    is the same as:

        [%= $variables{path}{to}{variable} + 1 %]

    but shorter and more readable.

    When no path is passed, the root of the input data is assumed to be a
    scalar and that will be returned.

    You can optionally pass a second parameter with a data structure. That
    will be used instead of the one provided to the template.

    You can look at this accessor as an alternate form for ["traverse"](#traverse),
    only with a slightly different input interface (e.g. defaulting to the
    template variables and swapped parameter positions).

## Direct Printing

Up to version 1.50, if you `print`ed (to `STDOUT`, which would be the
selected filehandle) your text would end up directly in the expanded
text. This was (and is still) meant as a feature.

As of version 1.52, this behaviour can change depending on the value of
option `stdout` (see ["new"](#new)). By default, its value is such that the
old behaviour is preserved: prints to `STDOUT` are trapped and put in
the template's expansion.

In case the new option `stdout` is set to a false value, though, any
`print` will use the currently selected filehandle before entering the
template, i.e. `STDOUT` (the _real_ one, not the one set within the
template) by default. This allows your code to actually communicate with
the external world, if you need to.

The following function allows you to still use a `print`-like interface
from within the template:

- **P**

        Hey [% P('foo-bar-baz') %], how are you?

    Print an expression directly to the template's expansion. Whatever the
    value of option `stdout` (see ["new"](#new)), this function will always put
    its argument inside the template.

    In case `stdout` is _true_ (which is the default value for backwards
    compatibility), `P` and `print` to `STDOUT` are equivalent (as a
    matter of fact, `P` just calls `print` to `STDOUT` behind the
    scenes).

    In case `stdout` is _false_, instead, `P` will send its output to the
    template, while `print` will send it to whatever handle is currently
    selectd, and `print` to `STDOUT` will use the `STDOUT` available at
    the time of template compilation.

    As an example, consider the following template:

        Hey '[% print 'foo' %]'
        I spoke with '[% print {*STDOUT} 'bar' %]'
        Do you know '[% P 'baz' %]'?

    If `stdout` is _true_, it will be expanded to:

        Hey 'foo'
        I spoke with 'bar'
        Do you know 'baz'?

    If `stdout` is _false_, it will be expanded to:

        Hey ''
        I spoke with ''
        Do you know 'baz'?

    while the string `foo` will be printed to the currently selected
    filehandle (which is usually `STDOUT`, but you might have something
    different in your program), and the string `bar` is printed to
    `STDOUT` as you know it.

## External Path Handling

The following functions can be exported and expose the algorithms
implemented by Template::Perlish for breaking a string into a path for
accessing a data structure, and a traversal function to go into a data
structure according to a path.

They can be useful in case you need to build the data structure to pass
to Template::Perlish before expanding a template. A typical case might
be that you have a command line option to set the value of variables in
the data structure to be expanded in the template:

    $ my-command --define path.to.1.variable=blah

and you want to apply the same algorithm as Template::Perlish, i.e. set
your data structure like this:

    $data->{path}{to}[1]{variable} = 'blah';

This will provide consistency when expanding the template, because using
the same path will provide the right value:

    [% path.to.1.variable %] expands to blah

- **crumble**

        my $array_ref = crumble($path);

    split the input `$path` into _crumbs_ that should be followed into
    some data structure (you can use ["traverse"](#traverse) to do the actual
    traversal). Returns a reference to an array with the crumbs, in order.
    Returns `undef` if the provided `$path` cannot be broken down. See
    ["Templates"](#templates) for the rules of breaking a path into pieces, this is the
    actual function used to do that.

- **traverse**

        my $x = traverse($data); # OR
        my $x = traverse($data \%opts); # OR
        my $x = traverse($data, $path); # OR
        my $x = traverse($data, $path, \%opts);

    traverse an input data structure and return _something_ (depending on
    the `$data`).

    The first argument `$data` is mandatory and can be:

    - _a HASH or ARRAY reference_, in which case a normal traversal will take
    place, and missing keys/indexes will stop the traversal;
    - _a reference to a SCALAR or to another REF_, in which case
    auto-vivification in traversal will be enabled (see below for details);
    - _anything else_, in which case it's better to either avoid `$path` or
    to provide an empty one to get it back, or it is likely to give an error
    (because you can't traverse it actually).

    When provided, `$path` is the path to follow inside `data`. It can be
    either a plain string that will be split using ["crumble"](#crumble), or an array
    reference containing the different _crumbs_ to follow. When missing, it
    is the same as providing the empty path (i.e. an empty string or a
    reference to an empty array).

    Depending on what is held in `$data`, you will get either a value back
    (if auto-vivification is NOT active) or a reference to it (if it is
    active). This also changes how the traversal is done in case of missing
    parts.

    In particular, you will want to pass a reference to a hash or array if
    you want to just _read_ from `data`. In this case, the first missing
    crumb will make the function return immediately an empty string value;
    moreover, if all crumbs are successfully found, the value will be
    returned. This is what is actually used by the functions described in
    ["Variables Accessors"](#variables-accessors).

    If you pass a reference to a scalar or to another reference instead, you
    will get back a reference to a value. In this case, any missing parts
    will trigger auto-vivification of the data structure, i.e. the missing
    parts will be created automatically for you. This comes handy when you
    want to _write_ into the data structure, like in the following example:

        my $empty_data;
        my $ref_to_v = traverse(\$empty_data, "some.0.'comp-lex'.path");
        $$ref_to_v = 42; # note double sigil for indirection
        # now we have that $empty_data is equal to:
        # { some => [ { 'comp-lex' => { path => 42 } } ] }

    You can e.g. want to use this approach to provide a consistent way to
    set variables and expand them into templates:

        my $vars;
        ${traverse(\$vars, 'one.two.3')} = 42;
        my $text = render('It is as simple as [% one.two.3 %]', $vars);

    Of course variable values might come from the command line or some other
    source in the real world!

    When something goes wrong in the traversal, `undef` is returned if
    auto-vivification is enabled, an empty string is returned otherwise.

    If `$path` is a reference to an array, its components can be plain
    scalars or references themselves. When they are plain scalars, they are
    used directly to access `data` or its descendants; otherwise,
    `traverse` enforces that the current descendant in `data` is a
    reference of the same type as the specific crumb. Consider this example:

        my $data = { one => { two => [ qw< ciao a tutti quanti > ] } }
        my $path1 = [ qw< one two 3 > ];           # good
        my $path2 = [ 'one', { two => 1 }, 3 ];    # good
        my $path3 = [ 'one', { two => 1 }, [3] ];  # good
        my $path4 = [ qw< one two >, { 3 => 1 } ]; # fails if !ref

    To get the `quanti` string, you have to traverse (in order) one hash,
    one hash and one array. The first path `$path1` is good to this regard,
    because it does not ask for any check and the last element is a good one
    to be used as an array index.

    `$path2` and `$path3` are good as well, because the required checks
    are fine: after passing `one` we end up with a hash, that is the same
    reference as `{ two => 1}` and gets us to the array reference.
    `$path3` asks for a further check that we are actually dealing with an
    array reference at this stage.

    `$path4` is not good because after traversing `one` and `two` we end
    up with an array reference. At this point, the next crumb is an hash
    reference instead (whose key is `3`), so the matching fails.

    As you have seen, if you are forcing a match on the reference type, the
    actual key used to dive into the relevant descendant of `data` is
    either the (only) element of an array reference (as in `[3]` that
    becomes `3`), or the (only) key of a hash reference (as in
    `{ two => 1 }` that becomes `two`).

    When auto-vivification is active, a reference in the `path` will also
    force a specific auto-vivification type, i.e. the automatic creation of
    either an array or a hash reference. If the crumb in `path` is not a
    reference, a guess is taken in that non-negative integers are considered
    indexes of an array, otherwise a hash is assumed. So, let's take
    `$path4` again, and let's see what happens when `ref` is true:

        my $path4 = [ qw< one two >, { 3 => 1 } ];
        my $data = {}; # start e.g. with an empty hash
        ${traverse(\$data, $path4)} = 42;

    will auto-vivify `$data` completely and leave it as follows:

        $data = {
           one => {        # "one" is not a non-negative integer => HASH
              two => {     # "two" is not a non-negative integer => HASH
                 3 => 42   # { 3 => 1 } is a hash reference      => HASH
              }
           }
        }

    As of version 1.52, you can also pass an extra hash reference with some
    additional options for traversal. For example, consider the following
    setup:

        sub what { return 'hey' };
        sub urgh { return 'gaah!' }
        my $object = bless {what => 'ever', foo => 'bar'}, __PACKAGE__;

    Object `$object` is a blessed hash reference with two keys, two methods
    and one method that has the same name of one of the keys. The different
    available options will help you decide what to do in this situation:

    - `method_over_key`

        when traversal by method is enabled (see `traverse_methods` below),
        this option allows controlling whether the key or the method win when
        both are present.

        In the example above, if this option is set to a _true_ value the path
        `what` triggers a method call; otherwise, the value in the hash is
        considered (i.e. `ever` in the example). When a key is not present, the
        method is called as a fallback.

        Defaults to a _false_ value.

    - `strict_blessed`

        when traversal by method is enabled (see below), whenever a blessed
        object is hit in the traversal only method calls are allowed. This
        disables _peeking_ inside the object in case a method is not available
        but a key exists.

        In the example above, using path `what` always triggers the method call
        (returning `hey`), using path `urgh` calls the method call, using path
        `foo` returns the empty string.

        This option hides option `method_over_key`.

        Defaults to a _false_ value.

    - `traverse_methods`

        boolean flag to enable traversal of blessed objects using method calls
        instead of direct inspection by key. When this is false, the other two
        options above are ignored.

        In the example object, if this parameter is set to a _false_ value the
        object will be considered just a plain hash. Otherwise, what a visit for
        keys `what`, `urgh` and `foo` returns depends on the options above.

        Defaults to a false value for backwards compatibility.

    The following scheme attempts to explain what happens in the different
    cases:

        traverse_methods = false (default)
          strict_blessed = whatever
        method_over_keys = whatever
            what -> 'ever'      # key is used, method is ignored
            foo  -> 'bar'       # key is used
            urgh -> ''          # method is ignored

        traverse_methods = true
          strict_blessed = false (default)
        method_over_keys = false (default)
            what -> 'ever'      # key wins over method
            foo  -> 'bar'       # key is used
            urgh -> 'gaah!'     # no key, method is called

        traverse_methods = true
          strict_blessed = false (default)
        method_over_keys = true
            what -> 'hey'       # method wins over key
            foo  -> 'bar'       # key is used
            urgh -> 'gaah!'     # method is called

        traverse_methods = true
          strict_blessed = true
        method_over_keys = whatever
            what -> 'hey'       # method wins over key
            foo  -> ''          # key is ignored
            urgh -> 'gaah!'     # method is called

# DIAGNOSTICS

Diagnostics have been improved in release 1.2 with respect to previous
versions, although there might still be some hiccups here and there.
Errors related to the template, in particular, will show you the
surrounding context of where the error has been detected, although the
exact line indication might be slightly wrong. You should be able to
find it anyway.

- `open(): %s`

    the only `perlfunc/open` is done to print stuff to a string. If you get
    this error, you're probably using a version of Perl that's too old.

- `unclosed %s at position %d`

    a Perl block was opened but not closed.

Other errors are generated as part of the Perl compilation, so they will
reflect the particular compile-time error encountered at that time.

# CONFIGURATION AND ENVIRONMENT

Template::Perlish requires no configuration files or environment
variables.

# DEPENDENCIES

None, apart a fairly recent version of Perl.

# INCOMPATIBILITIES

As of version 1.52, providing an empty template will give you back an
empty string, as opposed to `undef` that is the old behaviour.

# BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/

Due to the fact that Perl code is embedded directly into the template,
you have to take into consideration all the possible security
implications.  In particular, you should avoid taking templates from
outside, because in this case you'll be evaluating Perl code that you
haven't checked.  CAVEAT EMPTOR.

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# LICENSE AND COPYRIGHT

Copyright (c) 2008-2016 by Flavio Poletti `polettix@cpan.org`.

This module is free software.  You can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

# SEE ALSO

The best templating system in the world is undoubtfully
[Template::Toolkit](https://metacpan.org/pod/Template%3A%3AToolkit).

See
[http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html](http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html)
for a comparison (and a fairly complete list) of different templating
modules.
