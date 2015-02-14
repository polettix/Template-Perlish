package Template::Perlish;

$VERSION = '1.20';

use 5.008_000;
use warnings;
use strict;
use Carp;
use English qw( -no_match_vars );

# Function-oriented interface
sub import {
   my $package = shift;

   for my $sub (@_) {
      croak "subroutine '$sub' not exportable"
         unless grep { $sub eq $_ } qw( render );

      my $caller = caller();

      no strict 'refs';
      local $SIG{__WARN__} = \&Carp::carp;
      *{$caller . '::' . $sub} = \&{$package . '::' . $sub};
   }

   return;
}

sub render {
   my $template = shift;
   my (%variables, %params);
   if (@_) {
      %variables = ref($_[0]) ? %{shift @_} : splice @_, 0;
      %params = %{shift @_} if @_;
   }
   return __PACKAGE__->new(%params)->process($template, \%variables);
}

# Object-oriented interface
sub new {
   my $self = bless {
      start     => '[%',
      stop      => '%]',
      utf8      => 1,
      variables => {},
     },
     shift;
   %$self = (%$self, @_ == 1 ? %{$_[0]} : @_);
   return $self;
} ## end sub new

sub process {
   my ($self, $template, $vars) = @_;
   return $self->evaluate($self->compile($template), $vars);
}

sub evaluate {
   my ($self, $compiled, $vars) = @_;
   $self->_compile_sub($compiled)
      unless exists $compiled->{sub};
   return $compiled->{sub}->($vars);
} ## end sub evaluate

sub compile {
   my ($self, undef, %args) = @_;
   my $outcome = $self->_compile_code_text($_[1]);
   return $outcome if $args{no_check};
   return $self->_compile_sub($outcome);
}

sub compile_as_sub {
   my $self = shift;
   return $self->compile($_[0])->{'sub'};
} ## end sub compile_as_sub

sub _compile_code_text {
   my $self = shift;
   my ($template) = @_;

   my $starter = $self->{start};
   my $stopper = $self->{stop};

   my $compiled = "# line 1 'input'\n";
   $compiled .= "use utf8;\n\n" if $self->{utf8};
   $compiled .= "print {*STDOUT} '';\n\n";
   my $pos      = 0;
   my $line_no  = 1;
   while ($pos < length $template) {

      # Find starter and emit all previous text as simple text
      my $start = index $template, $starter, $pos;
      last if $start < 0;
      my $chunk = substr $template, $pos, $start - $pos;
      $compiled .= _simple_text($chunk)
        if $start > $pos;

      # Update scanning variables. The line counter is advanced for
      # the chunk but not yet for the $starter, so that error reporting
      # for unmatched $starter will point to the correct line
      $pos = $start + length $starter;
      $line_no += ($chunk =~ tr/\n//);

      # Grab code
      my $stop = index $template, $stopper, $pos;
      if ($stop < 0) { # no matching $stopper, bummer!
         my $section = _extract_section({ template => $template }, $line_no);
         die "unclosed starter '$starter' at line $line_no\n$section";
      }
      my $code = substr $template, $pos, $stop - $pos;

      # Now I can advance the line count considering the $starter too
      $line_no += ($starter =~ tr/\n//);

      if (length $code) {
         if ($code =~ m{\A\s* \w+(?:\.\w+)* \s*\z}mxs) {
            $compiled .= _variable($code);
         }
         elsif (my ($scalar) = $code =~ m{\A\s* (\$ [a-zA-Z_]\w*) \s*\z}mxs) {
            $compiled .= "\nprint {*STDOUT} $scalar; ### straight scalar\n\n";
         }
         elsif (substr($code, 0, 1) eq '=') {
            $compiled .= "\n# line $line_no 'template<3,$line_no>'\n" .
               _expression(substr $code, 1);
         }
         else {
            $compiled .= "\n# line $line_no 'template<0,$line_no>'\n" . $code;
         }
      }

      # Update scanning variables
      $pos = $stop + length $stopper;
      $line_no += (($code . $stopper) =~ tr/\n//);

   } ## end while ($pos < length $template)

   # put last part of input string as simple text
   $compiled .= _simple_text(substr($template, $pos || 0));

   return {
      template  => $template,
      code_text => $compiled,
   };
}

sub _compile_sub {
   my ($self, $outcome) = @_;

   {
      open my $fh, '>:raw', '/tmp/generated.pl'
         or die "open(): $OS_ERROR";
      print {$fh} $outcome->{code_text};
   }

   my @warnings;
   {
      my $utf8 = $self->{utf8} ? 1 : 0;
      local $SIG{__WARN__} = sub { push @warnings, @_ };
      $outcome->{sub} = eval <<"END_OF_CODE";
   sub {
      my \%variables = (\%{\$self->{variables}}, \%{shift || {}});
      local *STDOUT;
      open STDOUT, '>', \\my \$buffer or croak "open(): \$OS_ERROR";
      binmode STDOUT, ':encoding(utf8)' if $utf8;
      { # closure to "free" the \$buffer variable
$outcome->{code_text}
      }
      close STDOUT;
      if ($utf8) {
         require Encode;
         \$buffer = Encode::decode(utf8 => \$buffer);
      }
      return \$buffer;
   }
END_OF_CODE
      return $outcome if $outcome->{sub};
   }

   my $error = $EVAL_ERROR;
   my ($offset, $starter, $line_no) =
      $error =~ m{at\ 'template<(\d+),(\d+)>'\ line\ (\d+)}mxs;
   $line_no -= $offset;
   s{at\ 'template<\d+,\d+>'\ line\ (\d+)}{'at line ' . ($1 - $offset)}egmxs
      for @warnings, $error;
   if ($line_no == $starter) {
      s{,\ near\ "\#\ line.*?\n\s+}{, near "}gmxs
         for @warnings, $error;
   }

   my $section = _extract_section($outcome, $line_no);
   $error = join '', @warnings, $error, "\n", $section;

   die $error;
} ## end sub compile

sub _extract_section {
   my ($hash, $line_no) = @_;
   $line_no--; # for proper comparison with 0-based array
   my $start = $line_no - 3;
   my $end = $line_no + 3;

   my @lines = split /\n/, $hash->{template};
   $start = 0 if $start < 0;
   $end = $#lines if $end > $#lines;
   my $n_chars = length($end + 1);
   return join '', map {
      sprintf "%s%${n_chars}d| %s\n",
         (($_ == $line_no) ? '>>' : '  '),
         ($_ + 1),
         $lines[$_];
   } $start .. $end;
}

sub _simple_text {
   my $text = shift;

   return "print {*STDOUT} '$text';\n\n" if $text !~ /[\n'\\]/;

   $text =~ s/^/ /gms; # indent, trick taken from diff -u
   return <<"END_OF_CHUNK";
### Verbatim text
print {*STDOUT} do {
   my \$text = <<'END_OF_INDENTED_TEXT';
$text
END_OF_INDENTED_TEXT
   \$text =~ s/^ //gms;      # de-indent
   substr \$text, -1, 1, ''; # get rid of added newline
   \$text;
};

END_OF_CHUNK
} ## end sub _simple_text

sub _variable {
   my $path = shift;
   $path =~ s/\A\s+|\s+\z//mxsg;
   return <<"END_OF_CHUNK";
### Variable from \%variables stash
{
   my \$value = \\\%variables;
   for my \$chunk (split /\\./, '$path') {
      if (ref(\$value) eq 'HASH') {
         \$value = \$value->{\$chunk};
      }
      elsif (ref(\$value) eq 'ARRAY') {
         \$value = \$value->[\$chunk];
      }
      else {
         \$value = undef;
         last;
      }
   }
   print {*STDOUT} \$value if defined \$value;
}

END_OF_CHUNK
} ## end sub _variable

sub _expression {
   my $expression = shift;
   return <<"END_OF_CHUNK";
# Expression to be evaluated and printed out
{
   my \$value = do {{
$expression
   }};
   print {*STDOUT} \$value if defined \$value;
}

END_OF_CHUNK

}

1;    # Magic true value required at end of module
__END__

=encoding utf8

=head1 NAME

Template::Perlish - Yet Another Templating system for Perl

=head1 VERSION

This document describes Template::Perlish version 1.20. Most likely, this
version number here is outdate, and you should peek the source.


=head1 SYNOPSIS

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


=head1 SHOULD YOU USE THIS?

You're probably looking at the tons and tons of templating systems
available around - should you use this?

This system is quite basic and useful for simple situations. Say you
have a bunch of templates in which you want to put some variables -
then it's ok. On top of this, say that you want to add some simple
logic - like a couple of IF's or iterating over an array - then
it's ok again. For everything more complicated you should probably
look elsewhere.

As a summary:

=over

=item PRO

=over

=item *

lightweight, a single-file module with minimal requirements that you
can easily embed in your script;

=item *

simple approach to variable substitution, following 
L<Template::Toolkit|Template::Toolkit>
to cope with scalars, hashes and arrays;

=back

=item PRO/CON

=over

=item *

Perl code to handle all logic. This can be regarded as a PRO if you're
a Perl programmer, because you already know the syntax; this is
probably (definitively?) a CON in all other cases;

=back

=item CON

=over

=item *

you have to explicitly code everything that goes beyond simple variable
stuffing into a template.

=back

=back

If you think that this module does not fit your requirements,
my personal suggestion for a templating system is
L<Template::Toolkit|Template::Toolkit>: 
it's complete, easy to use and extensible, has excellent documentation 
(including a book and a quick reference guide) and support. Do you need 
anything more?

But don't trust me! Take a look at I<Choosing a Templating System> at
L<http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html>,
where you can find a fairly complete comparison about the I<streamline>
templating systems in Perl, and decide by yourself!

=head1 DESCRIPTION

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
included between C<[%> and C<%]> is considered as some sort of
I<command>, and treated specially. All the rest is treated as simple
text. Of course, you can modify the start and stop delimiter for a
command.

I<Commands> can be of four different types:

=over

=item B<variable embedding>

that are expanded with the particular value for a given C<variable>, where
C<variable>s are passed as a hash reference. A variable can be defined
as a sequence of alphanumeric (actually C<\w>) tokens, separated by dots.
The variables hash is visited considering each token as a subkey, in order
to let you visit complex data structures. You can also put arrays in, but
remember to use numbers ;)

=item B<scalar Perl variable>

that is expanded with the value of the given scalar variable;

=item B<Perl expression>

this MUST have a C<=> equal sign immediately after the opener, and
contain a valid Perl expression. This expression is evaluated
in scalar context and the result is printed;

=item B<code>

good old Perl code, in order to provide you with control structures,
modules, etc etc. This the most lazy approach I could think about, and
it's also why this module is called C<Perlish>.

=back

Take a look at the example in the L</SYNOPSIS>, it actually contains all
that this module provides.

To start, you'll need a C<Template::Perlish> object and, of course, a
template. Templates are provided as text strings; if you have them into
files, you are in charge of loading them first.

   # get a Template::Perlish object
   my $tp = Template::Perlish->new();

   # get the template (yes, it's your duty)
   my $tmpl = do { open my $fh, '<', 'filename'; local $/; <$fh> };

The basic operation mode is via the L</process> method, which works much
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

There is also a facility - namely C</compile_as_sub> - that returns an
anonymous sub that encapsulates the C<evaluate> call above:

   my $sub = $tp->compile_as_sub($template)
      or die "template did not compile: $EVAL_ERROR";
   for my $dataset (@available_data) {
      print {*STDOUT} "DATASET\n", $sub->($dataset), "\n\n";
   }

As of release 1.2 the error reporting facility has been improved to
provide feedback if there are issues with the provided template, e.g.
when there is a syntax error in the Perl code inside. When an error
arises, the module will C<die()> with a meaningful message about where
the error is. This happens with all the provided facilities.

Error checking is turned on automatically on all facilities. You can
avoid doing it in the C</compile> method, although the check will kick
in at the first usage of the compiled form. To avoid the check upon
the compilation, pass the C<no_check> option to L</compile>:

   my $compiled = $tp->compile($template, no_check => 1);

=head1 INTERFACE 

=head2 One Shot Templates

The following convenience function can be used to quickly render a
template:

=over

=item B<render>

   use Template::Perlish qw( render );
   my $rendered = render($template);             # OR
   my $rendered = render($template, %variables); # OR
   my $rendered = render($template, \%variables);

if you already have a template and the variables to fill it in, this
is probably the quickest thing to do.

You can pass the template alone, or you can pass the variables as
well, either as a flat list (that will be converted back to a hash)
or as a single hash reference.

Returns the rendered template, i.e. the same output as L</process>.

=back

=head2 Constructor

=over

=item B<new>

   $tp = Template::Perlish->new(%opts); # OR
   $tp = Template::Perlish->new(\%opts);

constructor, does exactly what you think. You can provide any parameter,
but only the following will make sense:

=over

=item I<start>

delimiter for the start of a I<command> (as opposed to plain text/data);

=item I<stop>

delimiter for the end of a I<command>;

=item I<variables>

variables that will be passed to all invocations of L</process> and/or
L</evaluate>.

=back

Parameters can be given directly or via a hash reference.

By default, the delimiters are the same as TT2, i.e. C<[%> and C<%]>, and
the variables hash is empty.

The return value is a reference to an anonymous hash, whose three
elements are the ones described above. You can modify them at will.

=back

=head2 Template Handling

=over

=item B<compile>

   $compiled = $tp->compile($template);
   $compiled = $tp->compile($template, no_check => $boolean);

compile a template generating the relevant Perl code. Using this method
is useful when the same template has to be used multiple times, so the
compilation can be done one time only.

You can turn off checking using the c<no_check> optional parameter and
passing a true value. The check will be performed upon the first
usage of the compiled form though.

Returns a hash containing, among the rest, a text version of the
template transformed into Perl code.

=item B<compile_as_sub>

   $sub_reference = $tp->compile_as_sub($template);

Much like L</compile>, this method does exactly the same compilation,
but returns a reference to an anonymous subroutine that can be used
each time you want to "explode" the template. 

The anonymous sub that is returned accepts a single, optional parameter,
namely a reference to a hash of variables to be used in addition to the
"streamline" ones.

Note that if you add/change/remove values using the C<variables> member
of the Template::Perlish object, these changes will reflect on the
anonymous sub, so you end up using different values in two subsequent
invocations of the sub. This is consistent with the behaviuor of the
L</evaluate> method.

=item B<evaluate>

   $final_text = $tp->evaluate($compiled); # OR
   $final_text = $tp->evaluate($compiled, \%variables);

evaluate a template (in its compiled form, see L</compile>) with the
available variables. In the former form, only the already configured
variables are used; in the latter, the given C<$variables> (which is
a hash reference) are added, overriding any corresponding key.

Returns the processed text as a string.

=item B<process>

   $final_text = $tp->process($template); # OR
   $final_text = $tp->process($template, $variables);

this method included L</compile> and L</evaluate> into a single step.

=back

=head2 Templates

There's really very little to say: write your document/text/whatever, and
embed special parts with the delimiters of your choice (or stick to the
defaults). If you have to print stuff, just print to STDOUT, it will
be automatically catpured (unless you're calling the generated
code by yourself).

Anything inside these "special" parts matching the regular 
expression /^\s*\w+(?:\.\w+)*\s*$/, i.e. consisting only of a sequence
of alphanumeric tokens separated by dots, are considered to be variables
and processed accordingly. Thus, available variables can be accessed 
in two ways: using the dotted notation, as in

   [% some.value.3.lastkey %]

or explicitly using the C<%variables> hash:

   [% print $variables{some}{value}[3]{lastkey} %]

The former is cleaner, but the latter is more powerful of course.

If you happen to have a value you want to print inside a simple scalar
variable, instead of:

   [% print $variable; %]

you can also you the short form:

  [% $variable %]

Note: only the scalar variable name, nothing else apart optional spaces.
If you have something fancier, i.e. a Perl expression, you can use a
shortcut to evaluate it and print all in one single command:

  [%= my $value = 100; "*** $variable -> $value ***" %]

Note that there is an equal sign (C<">) immediately after the command
opener C<[%>. The Perl expression is evaluated in scalar context, and
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

Take care to always terminate your commands with a C<;> each time
you would do it in actual code.

There's no escaping mechanism, so if you want to include literal
C<[%> or C<%]> you either have to change delimiters, or you have to
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

=head1 DIAGNOSTICS

Diagnostics have been improved in release 1.2 with respect to previous
versions, although there might still be some hiccups here and there.
Errors related to the template, in particular, will show you the
surrounding context of where the error has been detected, although the
exact line indication might be slightly wrong. You should be able to
find it anyway.

=over

=item C<< open(): %s >>

the only C<perlfunc/open> is done to print stuff to a string.
If you get this error, you're probably using a version of Perl that's
too old.

=item C<< unclosed %s at position %d >>

a Perl block was opened but not closed.

=back

Other errors are generated as part of the Perl compilation, so they
will reflect the particular compile-time error encountered at that time.


=head1 CONFIGURATION AND ENVIRONMENT

Template::Perlish requires no configuration files or environment variables.


=head1 DEPENDENCIES

None, apart a fairly recent version of Perl.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/

Due to the fact that Perl code is embedded directly into the template,
you have to take into consideration all the possible security implications.
In particular, you should avoid taking templates from outside, because
in this case you'll be evaluating Perl code that you haven't checked.
CAVEAT EMPTOR.

=head1 AUTHOR

Flavio Poletti <polettix@cpan.org>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, 2015 by Flavio Poletti polettix@cpan.org.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=head1 SEE ALSO

The best templating system in the world is undoubtfully L<Template::Toolkit>.

See L<http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html>
for a comparison (and a fairly complete list) of different templating modules.

=cut
