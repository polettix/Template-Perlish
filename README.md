# NAME

Template::Perlish - Yet Another Templating system for Perl

# VERSION

This document describes Template::Perlish version 1.40.

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
       items => [ qw( ciao a tutti quanti ) ],
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

    use Template::Perlish qw( render );
    my $rendered = render($template, \%variables);

# SHOULD YOU USE THIS?

You're probably looking at the tons and tons of templating systems
available around - should you use this?

This system is quite basic and useful for simple situations. Say you
have a bunch of templates in which you want to put some variables -
then it's ok. On top of this, say that you want to add some simple
logic - like a couple of IF's or iterating over an array - then
it's ok again. For everything more complicated you should probably
look elsewhere.

As a summary:

- PRO
    - lightweight, a single-file module with minimal requirements that you
    can easily embed in your script;
    - simple approach to variable substitution, following
    [Template::Toolkit](https://metacpan.org/pod/Template::Toolkit)
    to cope with scalars, hashes and arrays;
- PRO/CON
    - Perl code to handle all logic. This can be regarded as a PRO if you're
    a Perl programmer, because you already know the syntax; this is
    probably (definitively?) a CON in all other cases;
- CON
    - you have to explicitly code everything that goes beyond simple variable
    stuffing into a template.
    - if you care about security, you MUST look elsewhere. There are _string_
    `eval`s inside Template::Perlish, so you must be 100% or more sure that
    you trust your templates. Don't trust them if you don't write them
    yourself, and even in that case be suspicious.

If you think that this module does not fit your requirements,
my personal suggestion for a templating system is
[Template::Toolkit](https://metacpan.org/pod/Template::Toolkit):
it's complete, easy to use and extensible, has excellent documentation
(including a book and a quick reference guide) and support. Do you need
anything more?

But don't trust me! Take a look at _Choosing a Templating System_ at
[http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html](http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html),
where you can find a fairly complete comparison about the _streamline_
templating systems in Perl, and decide by yourself!

# DESCRIPTION

You bet, this is another templating system for Perl. Yes, because
it's the dream of every Perl programmer, me included. I needed something
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

    that are expanded with the particular value for a given `variable`, where
    `variable`s are passed as a hash reference. A variable can be defined
    as a sequence of alphanumeric (actually `\w`) tokens, separated by dots.
    The variables hash is visited considering each token as a subkey, in order
    to let you visit complex data structures. You can also put arrays in, but
    remember to use numbers ;)

- **scalar Perl variable**

    that is expanded with the value of the given scalar variable;

- **Perl expression**

    this MUST have a `=` equal sign immediately after the opener, and
    contain a valid Perl expression. This expression is evaluated
    in scalar context and the result is printed;

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

Each template is transformed into Pure Perl code, then the code
is evaluated in order to get the output. Thus, if you want to operate
on the same template many times, a typical usage is:

    # compile the template with something like:
    my $compiled = $tp->compile($template);

    # use the compiled template multiple times with different data
    for my $dataset (@available_data) {
       print "DATASET\n", $tp->evaluate($compiled, $dataset), "\n\n";
    }

There is also a facility - namely `/compile_as_sub` - that returns an
anonymous sub that encapsulates the `evaluate` call above:

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
avoid doing it in the `/compile` method, although the check will kick
in at the first usage of the compiled form. To avoid the check upon
the compilation, pass the `no_check` option to ["compile"](#compile):

    my $compiled = $tp->compile($template, no_check => 1);

# INTERFACE 

## One Shot Templates

The following convenience function can be used to quickly render a
template:

- **render**

        use Template::Perlish qw( render );
        my $rendered = render($template);             # OR
        my $rendered = render($template, %variables); # OR
        my $rendered = render($template, \%variables);

    if you already have a template and the variables to fill it in, this
    is probably the quickest thing to do.

    You can pass the template alone, or you can pass the variables as
    well, either as a flat list (that will be converted back to a hash)
    or as a single hash reference.

    Returns the rendered template, i.e. the same output as ["process"](#process).

## Constructor

- **new**

        $tp = Template::Perlish->new(%opts); # OR
        $tp = Template::Perlish->new(\%opts);

    constructor, does exactly what you think. You can provide any parameter,
    but only the following will make sense:

    - _start_

        delimiter for the start of a _command_ (as opposed to plain text/data);

    - _stop_

        delimiter for the end of a _command_;

    - _variables_

        variables that will be passed to all invocations of ["process"](#process) and/or
        ["evaluate"](#evaluate).

    Parameters can be given directly or via a hash reference.

    By default, the delimiters are the same as TT2, i.e. `[%` and `%]`, and
    the variables hash is empty.

    The return value is a reference to an anonymous hash, whose three
    elements are the ones described above. You can modify them at will.

## Template Handling

- **compile**

        $compiled = $tp->compile($template);
        $compiled = $tp->compile($template, no_check => $boolean);

    compile a template generating the relevant Perl code. Using this method
    is useful when the same template has to be used multiple times, so the
    compilation can be done one time only.

    You can turn off checking using the c<no\_check> optional parameter and
    passing a true value. The check will be performed upon the first
    usage of the compiled form though.

    Returns a hash containing, among the rest, a text version of the
    template transformed into Perl code.

- **compile\_as\_sub**

        $sub_reference = $tp->compile_as_sub($template);

    Much like ["compile"](#compile), this method does exactly the same compilation,
    but returns a reference to an anonymous subroutine that can be used
    each time you want to "explode" the template.

    The anonymous sub that is returned accepts a single, optional parameter,
    namely a reference to a hash of variables to be used in addition to the
    "streamline" ones.

    Note that if you add/change/remove values using the `variables` member
    of the Template::Perlish object, these changes will reflect on the
    anonymous sub, so you end up using different values in two subsequent
    invocations of the sub. This is consistent with the behaviuor of the
    ["evaluate"](#evaluate) method.

- **evaluate**

        $final_text = $tp->evaluate($compiled); # OR
        $final_text = $tp->evaluate($compiled, \%variables);

    evaluate a template (in its compiled form, see ["compile"](#compile)) with the
    available variables. In the former form, only the already configured
    variables are used; in the latter, the given `$variables` (which is
    a hash reference) are added, overriding any corresponding key.

    Returns the processed text as a string.

- **process**

        $final_text = $tp->process($template); # OR
        $final_text = $tp->process($template, $variables);

    this method included ["compile"](#compile) and ["evaluate"](#evaluate) into a single step.

## Templates

There's really very little to say: write your document/text/whatever, and
embed special parts with the delimiters of your choice (or stick to the
defaults). If you have to print stuff, just print to STDOUT, it will
be automatically catpured (unless you're calling the generated
code by yourself).

Anything inside these "special" parts matching the regular
expression /^\\s\*\\w+(?:\\.\\w+)\*\\s\*$/, i.e. consisting only of a sequence
of alphanumeric tokens separated by dots, are considered to be variables
and processed accordingly. Thus, available variables can be accessed
in two ways: using the dotted notation, as in

    [% some.value.3.lastkey %]

or explicitly using the `%variables` hash:

    [% print $variables{some}{value}[3]{lastkey} %]

The former is cleaner, but the latter is more powerful of course.

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
the result is printed (if defined, otherwise it's skipped). This sort
of makes the previous short form for simple scalars a bit outdated,
but you spare a character in any case and it's just DWIM.

If you know Perl, you should not have problems using the control structures.
Just intersperse the code with the templates as you would normally do
in any other templating system:

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

Take care to always terminate your commands with a `;` each time
you would do it in actual code.

As of version 1.40, there are also a few functions that will make your
life easy if you want to access the variables, namely ["V"](#v) to access a
variable provided its dotted-path representation, ["A"](#a) for expanding
the variable as an array, ["H"](#h) to expand it as a hash, and ["HK"](#hk) and
["HV"](#hv) to get the keys and values of a hash, respectively.

There's no escaping mechanism, so if you want to include literal
`[%` or `%]` you either have to change delimiters, or you have to
resort to tricks. In particular, a stray closing inside a textual part
won't be a problem, e.g.:

    [% print "variable"; %] %] [% print "another"; %]

prints:

    variable %] another

The tricky part is including the closing in the Perl code, but there
can be many tricks:

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

- **A**

        A 'path.to.arrayref'

    get the variable at the specific path and expand it as array. This can
    be useful if you want to iterate over a variable that you know is an
    array reference:

        [% for my $item (A 'my.array') { ... } %]

    is equivalent to:

        [% for my $item (@{$variables{my}{array}}) { ... } %]

    but more concise and a little more readable.

- **H**

        H 'path.to.hashref'

    get the variable at the specific path and expand it as hash.

- **HK**

        HK 'path.to.hashref'

    get the variable at the specific path, expand it as hash and get its
    keys. This can be useful if you want to iterate over the keys of a
    variable that you know is an hash reference:

        [% for my $key (HK 'my.hash') { ... } %]

    is equivalent to:

        [% for my $key (keys %{$variables{my}{hash}}) { ... } %]

    but more concise and a bit more readable.

- **HV**

        HV 'path.to.hashref'

    similar to ["HK"](#hk), but provides values instead of keys.

- **V**

        V 'path.to.variable'

    get the variable at the specific path. The following:

        [%= V('path.to.variable') + 1 %]

    is the same as:

        [%= $variables{path}{to}{variable} + 1 %]

    but shorter and more readable.

# DIAGNOSTICS

Diagnostics have been improved in release 1.2 with respect to previous
versions, although there might still be some hiccups here and there.
Errors related to the template, in particular, will show you the
surrounding context of where the error has been detected, although the
exact line indication might be slightly wrong. You should be able to
find it anyway.

- `open(): %s`

    the only `perlfunc/open` is done to print stuff to a string.
    If you get this error, you're probably using a version of Perl that's
    too old.

- `unclosed %s at position %d`

    a Perl block was opened but not closed.

Other errors are generated as part of the Perl compilation, so they
will reflect the particular compile-time error encountered at that time.

# CONFIGURATION AND ENVIRONMENT

Template::Perlish requires no configuration files or environment variables.

# DEPENDENCIES

None, apart a fairly recent version of Perl.

# INCOMPATIBILITIES

None reported.

# BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/

Due to the fact that Perl code is embedded directly into the template,
you have to take into consideration all the possible security implications.
In particular, you should avoid taking templates from outside, because
in this case you'll be evaluating Perl code that you haven't checked.
CAVEAT EMPTOR.

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# LICENSE AND COPYRIGHT

Copyright (c) 2008-2015 by Flavio Poletti `polettix@cpan.org`.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

# SEE ALSO

The best templating system in the world is undoubtfully
[Template::Toolkit](https://metacpan.org/pod/Template::Toolkit).

See
[http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html](http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html)
for a comparison (and a fairly complete list) of different templating
modules.
