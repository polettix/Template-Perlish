package Template::Perlish;

use version; our $VERSION = qv('0.0.1');

use warnings;
use strict;
use Carp;
use English qw( -no_match_vars );

# Module implementation here
sub new {
   my $self = bless {
      start => '[%',
      stop  => '%]',
      variables => {},
     },
     shift;
   %$self = (%$self, @_ == 1 ? %{$_[0]} : @_);
   return $self;
} ## end sub new

sub get_start { return shift->{start}; }
sub get_stop  { return shift->{stop}; }

sub set_start {
   my ($self, $value) = @_;
   $self->{start} = $value;
}

sub set_stop {
   my ($self, $value) = @_;
   $self->{stop} = $value;
}

sub get_variables {
   my $v = shift->{variables};
   return $v unless wantarray;
   return %$v;
}

sub set_variables {
   my ($self, $value) = @_;
   $self->{variables} = $value;
}

sub set_variable {
   my ($self, $name, $value) = @_;
   $self->get_variables()->{$name} = $value;
}

sub process {
   my $self = shift;
   my ($template, $vars) = @_;

   my $compiled = $self->compile($template);
   # print {*STDERR} "COMPILED:\n$compiled\n";

   local *STDOUT;
   open STDOUT, '>', \my $buffer or die "open(): $OS_ERROR";
   my %variables = ($self->get_variables(), %{$vars || {}});
   eval $compiled;
   return $buffer;
} ## end sub process

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
}

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
}

sub compile {
   my $self = shift;
   my ($template) = @_;

   my $starter = $self->get_start();
   my $stopper = $self->get_stop();

   my $compiled = '';
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

1;    # Magic true value required at end of module
__END__

=head1 NAME

Template::Perlish - [Una riga di descrizione dello scopo del modulo]


=head1 VERSION

This document describes Template::Perlish version 0.0.1. Most likely, this
version number here is outdate, and you should peek the source.


=head1 SYNOPSIS

   use Template::Perlish;

=for l'autore, da riempire:
   Qualche breve esempio con codice che mostri l'utilizzo più comune.
   Questa sezione sarà quella probabilmente più letta, perché molti
   utenti si annoiano a leggere tutta la documentazione, per cui
   è meglio essere il più educativi ed esplicativi possibile.
  
  
=head1 DESCRIPTION

=for l'autore, da riempire:
   Fornite una descrizione completa del modulo e delle sue caratteristiche.
   Aiutatevi a strutturare il testo con le sottosezioni (=head2, =head3)
   se necessario.


=head1 INTERFACE 

=for l'autore, da riempire:
   Scrivete una sezione separata che elenchi i componenti pubblici
   dell'interfaccia del modulo. Questi normalmente sono formati o
   dalle subroutine che possono essere esportate, o dai metodi che
   possono essere chiamati su oggetti che appartengono alle classi
   fornite da questo modulo.


=head1 DIAGNOSTICS

=for l'autore, da riempire:
   Elencate qualunque singolo errore o messaggio di avvertimento che
   il modulo può generare, anche quelli che non "accadranno mai".
   Includete anche una spiegazione completa di ciascuno di questi
   problemi, una o più possibili cause e qualunque rimedio
   suggerito.


=over

=item C<< Error message here, perhaps with %s placeholders >>

[Descrizione di un errore]

=item C<< Another error message here >>

[Descrizione di un errore]

[E così via...]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for l'autore, da riempire:
   Una spiegazione completa di qualunque sistema di configurazione
   utilizzato dal modulo, inclusi i nomi e le posizioni dei file di
   configurazione, il significato di ciascuna variabile di ambiente
   utilizzata e proprietà che può essere impostata. Queste descrizioni
   devono anche includere dettagli su eventuali linguaggi di configurazione
   utilizzati.
  
Template::Perlish requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for l'autore, da riempire:
   Una lista di tutti gli altri moduli su cui si basa questo modulo,
   incluse eventuali restrizioni sulle relative versioni, ed una
   indicazione se il modulo in questione è parte della distribuzione
   standard di Perl, parte della distribuzione del modulo o se
   deve essere installato separatamente.

None.


=head1 INCOMPATIBILITIES

=for l'autore, da riempire:
   Una lista di ciascun modulo che non può essere utilizzato
   congiuntamente a questo modulo. Questa condizione può verificarsi
   a causa di conflitti nei nomi nell'interfaccia, o per concorrenza
   nell'utilizzo delle risorse di sistema o di programma, o ancora
   a causa di limitazioni interne di Perl (ad esempio, molti dei
   moduli che utilizzano filtri al codice sorgente sono mutuamente
   incompatibili).

None reported.


=head1 BUGS AND LIMITATIONS

=for l'autore, da riempire:
   Una lista di tutti i problemi conosciuti relativi al modulo,
   insime a qualche indicazione sul fatto che tali problemi siano
   plausibilmente risolti in una versione successiva. Includete anche
   una lista delle restrizioni sulle funzionalità fornite dal
   modulo: tipi di dati che non si è in grado di gestire, problematiche
   relative all'efficienza e le circostanze nelle quali queste possono
   sorgere, limitazioni pratiche sugli insiemi dei dati, casi
   particolari che non sono (ancora) gestiti, e così via.

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/


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
