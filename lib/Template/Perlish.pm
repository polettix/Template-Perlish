package Template::Perlish;

$VERSION = '1.0';

use warnings;
use strict;
use Carp;
use English qw( -no_match_vars );

# Module implementation here
sub new {
   my $self = bless {
      start     => '[%',
      stop      => '%]',
      variables => {},
     },
     shift;
   %$self = (%$self, @_ == 1 ? %{$_[0]} : @_);
   return $self;
} ## end sub new

sub get_start { return shift->{start}; }

sub set_start {
   my ($self, $value) = @_;
   $self->{start} = $value;
   return;
}

sub get_stop { return shift->{stop}; }

sub set_stop {
   my ($self, $value) = @_;
   $self->{stop} = $value;
   return;
}

sub get_variables {
   my $v = shift->{variables};
   return $v unless wantarray;
   return %$v;
}

sub set_variables {
   my $self = shift;
   if (@_ == 1) {
      $self->{variables} = shift;
   }
   else {
      %{$self->{variables}} = @_;
   }
   return;
}

sub set_variable {
   my ($self, $name, $value) = @_;
   $self->get_variables()->{$name} = $value;
   return;
}

sub process {
   my ($self, $template, $vars) = @_;
   return $self->evaluate($self->compile($template), $vars);
} ## end sub process

sub evaluate {
   my $self = shift;
   my ($compiled, $vars) = @_;

   local *STDOUT;
   open STDOUT, '>', \my $buffer or croak "open(): $OS_ERROR";
   my %variables = ($self->get_variables(), %{$vars || {}});
   eval $compiled;
   return $buffer;
}

sub compile {
   my $self = shift;
   my ($template) = @_;

   my $starter = $self->get_start();
   my $stopper = $self->get_stop();

   my $compiled = "print {*STDOUT} '';\n\n";
   my $pos      = 0;
   while ($pos < length $template) {

      # Find starter and emit all previous text as simple text
      my $start = index $template, $starter, $pos;
      last if $start < 0;
      $compiled .= _simple_text(substr $template, $pos, $start - $pos)
        if $start > $pos;
      $pos = $start + length $starter;

      # Grab code
      my $stop = index $template, $stopper, $pos;
      croak "unclosed $starter at position $pos" if $stop < 0;
      my $code = substr $template, $pos, $stop - $pos;
      $pos = $stop + length $stopper;

      next unless length $code;
      if ($code =~ m{\A\s* \w+(?:\.\w+)* \s*\z}mxs) {
         $compiled .= _variable($code);
      }
      else {
         $compiled .= $code;
      }
   } ## end while ($pos < length $template)
   $compiled .= _simple_text(substr($template, $pos || 0));

   return $compiled;
} ## end sub compile

sub _simple_text {
   my $text = shift;
   $text =~ s/^/ /gms;
   return <<"END_OF_CHUNK";
####################################################
###
### Verbatim text
print {*STDOUT} do {
   my \$text = <<'END_OF_INDENTED_TEXT';
$text
END_OF_INDENTED_TEXT
   \$text =~ s/^ //gms;
   substr \$text, -1, 1, '';
   \$text;
};

END_OF_CHUNK
} ## end sub _simple_text

sub _variable {
   my $path = shift;
   $path =~ s/\A\s+|\s+\z//mxsg;
   return <<"END_OF_CHUNK";
####################################################
###
### Find path inside variables stash
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
   \$value = '' unless defined \$value;
   print {*STDOUT} \$value;
}

END_OF_CHUNK
} ## end sub _variable

1;    # Magic true value required at end of module
__END__

=head1 NAME

Template::Perlish - Yet Another Templating system for Perl


=head1 VERSION

This document describes Template::Perlish version 1.0. Most likely, this
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
      for my $item (@$items) {%]
      * [% print $item;
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

   # The above prints:
   #
   #   Dear Ciccio Riccio,
   #   
   #      we are pleased to present you the following items:
   #   
   #      * ciao
   #      * a
   #      * tutti
   #      * quanti
   #   
   #   Please consult our complete catalog at http://whateeeeever/.
   #   
   #   Yours,
   #   
   #       Poletti.

=head1 DESCRIPTION

You bet, this is another templating system for Perl. Yes, because
it's the dream of every Perl programmer, me included. I needed something
that's easily portable, with no dependencies apart a recent Perl version
(but with some tweaking this should be solved), much in the spirit of
the ::Tiny modules. And yes, my dream is to fill that ::Tiny gap some
time in the future, but with another module.

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

I<Commands> can be of two different types:

=over

=item B<variable embedding>

that are expanded with the particular value for a given C<variable>, where
C<variable>s are passed as a hash reference. A variable can be defined
as a sequence of alphanumeric (actually C<\w>) tokens, separated by dots.
The variables hash is visited considering each token as a subkey, in order
to let you visit complex data structures. You can also put arrays in, but
remember to use numbers ;)

=item B<code>

good old Perl code, in order to provide you with control structures,
modules, etc etc. This the most lazy approach I could think about, and
it's also why this module is called C<Perlish>.

=back

Take a look at the example in the L<SYNOPSIS>, it actually contains all
that this module provides.

To start, you'll need a C<Template::Perlish> object and, of course, a
template. Templates are provided as text strings; if you have them into
files, you are in charge of loading them first.

   # get a Template::Perlish object
   my $tp = Template::Perlish->new();

   # get the template (yes, it's your duty)
   my $tmpl = do { open my $fh, '<', 'filename'; local $/; <$fh> };

The basic operation mode is via the L<process()> method, which works much
like in TT2. Anyway, this method will always give you back the generated
stuff, and won't print anything. This can probably be less memory
efficient when big templates are involved, but in this case you should
probably head somewhere else.

   # print out the template filled with some variables
   print $tp->process($tmpl, { key => 'value' });

Each template is transformed into Pure Perl code, then the code
is evaluated in order to get the output. Thus, if you want to operate
on the same template many times, a typical usage is:

   # compile the template with something like:
   my $compiled = $tp->compile($template);

   # use the compiled template multiple times with different data
   for my $dataset (@available_data) {
      print {*STDOUT} "DATASET\n", $tp->evaluate($dataset), "\n\n";
   }


=head1 INTERFACE 

=head2 Constructor and Accessors

=over

=item B<< new(%opts) >>

=item B<< new(\%opts) >>

constructor, does exactly what you think. You can provide any parameter,
but only the following will make sense:

=over

=item I<< start >>

delimiter for the start of a I<command> (as opposed to plain text/data);

=item I<< stop >>

delimiter for the end of a I<command>;

=item I<< variables >>

variables that will be passed to all invocations of L<process()> and/or
L<evaluate()>.

=back

Parameters can be given directly or via a hash reference.

By default, the delimiters are the same as TT2, i.e. C<[%> and C<%]>, and
the variables hash is empty.

=item B<< get_start(), set_start($value) >>

=item B<< get_stop(), set_stop($value) >>

accessors for the delimiters (see L<new()>).


=item B<< get_variables() >>

get the configured variables. These variables will be available to all
invocations of either C<process()> or C<evaluate()>.

When called in scalar context returns a reference to the hash containing
the variables. You can set variables directly on the hash. In list
context the whole hash will be returned (as a shallow copy).

=item B<< set_variables(%new_values) >>

=item B<< set_variables(\%new_values) >>

set variables common to all subsequent invocations. You can pass either
the new contents for the hash, or a reference to the hash to be used.


=item B<< set_variable($name, $value) >>

set a single variable's value, among the variables that are passed to
all invocations.

=back

=head2 Template Handling

=over

=item B<< compile($template) >>

compile a template generating the relevant Perl code. Using this method
is useful when the same template has to be used multiple times, so the
compilation can be done one time only.

Please note that the generated Perl code will be parsed each time you
use it, of course.

Returns a text containing Perl code.

=item B<< evaluate($compiled) >>

=item B<< evaluate($compiled, $variables) >>

evaluate a template (in its compiled for, see L<compile()>) with the
available variables. In the former form, only the already configured
variables are used; in the latter, the given C<$variables> (which is
a hash reference) are added, overriding any matching key.

Returns the processed text as a string.

=item B<< process($template) >>

=item B<< process($template, $variables) >>

this method included L<compile()> and L<evaluate()> into a single step.

=back

=head2 Templates

There's really very little to say.

Available variables can be accessed in two ways: using the dotted notation,
as in

   [% some.value.3.lastkey %]

or explicitly using the C<%variables> hash:

   [% print $variables{some}{value}[3]{lastkey} %]

The former is cleaner, but the latter is more powerful of course.

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

   here it comes [% print '[%'; %] the delimiter

prints:

   here it comes [% the delimiter

Another trick is to separate the two chars with an empty block:

   here it comes [[%%]%

Including the starter in the Perl code is not a problem, of course.

So the bottom line is: who needs escaping?

=head1 DIAGNOSTICS

Unfortunately, the diagnostic is still quite poor.

=over

=item C<< open(): %s >>

the only C<open()> is done to print stuff to a string. If you get this
error, you're probably using a version of Perl that's too old.

=item C<< unclosed %s at position %d >>

a Perl block was opened but not closed.

=back


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

=head1 AUTHOR

Flavio Poletti  C<< <flavio [at] polettix [dot] it> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Flavio Poletti C<< <flavio [at] polettix [dot] it> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>
and L<perlgpl>.

Questo modulo è software libero: potete ridistribuirlo e/o
modificarlo negli stessi termini di Perl stesso. Vedete anche
L<perlartistic> e L<perlgpl>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 NEGAZIONE DELLA GARANZIA

Poiché questo software viene dato con una licenza gratuita, non
c'è alcuna garanzia associata ad esso, ai fini e per quanto permesso
dalle leggi applicabili. A meno di quanto possa essere specificato
altrove, il proprietario e detentore del copyright fornisce questo
software "così com'è" senza garanzia di alcun tipo, sia essa espressa
o implicita, includendo fra l'altro (senza però limitarsi a questo)
eventuali garanzie implicite di commerciabilità e adeguatezza per
uno scopo particolare. L'intero rischio riguardo alla qualità ed
alle prestazioni di questo software rimane a voi. Se il software
dovesse dimostrarsi difettoso, vi assumete tutte le responsabilità
ed i costi per tutti i necessari servizi, riparazioni o correzioni.

In nessun caso, a meno che ciò non sia richiesto dalle leggi vigenti
o sia regolato da un accordo scritto, alcuno dei detentori del diritto
di copyright, o qualunque altra parte che possa modificare, o redistribuire
questo software così come consentito dalla licenza di cui sopra, potrà
essere considerato responsabile nei vostri confronti per danni, ivi
inclusi danni generali, speciali, incidentali o conseguenziali, derivanti
dall'utilizzo o dall'incapacità di utilizzo di questo software. Ciò
include, a puro titolo di esempio e senza limitarsi ad essi, la perdita
di dati, l'alterazione involontaria o indesiderata di dati, le perdite
sostenute da voi o da terze parti o un fallimento del software ad
operare con un qualsivoglia altro software. Tale negazione di garanzia
rimane in essere anche se i dententori del copyright, o qualsiasi altra
parte, è stata avvisata della possibilità di tali danneggiamenti.

Se decidete di utilizzare questo software, lo fate a vostro rischio
e pericolo. Se pensate che i termini di questa negazione di garanzia
non si confacciano alle vostre esigenze, o al vostro modo di
considerare un software, o ancora al modo in cui avete sempre trattato
software di terze parti, non usatelo. Se lo usate, accettate espressamente
questa negazione di garanzia e la piena responsabilità per qualsiasi
tipo di danno, di qualsiasi natura, possa derivarne.

=cut
