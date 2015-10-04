package Template::Perlish;

use 5.008_000;
use warnings;
use strict;
use Carp;
use English qw( -no_match_vars );
use constant ERROR_CONTEXT => 3;
{ our $VERSION = '1.41'; }

# Function-oriented interface
sub import {    ## no critic (RequireArgUnpacking)
   my $package = shift;

   for my $sub (@_) {
      croak "subroutine '$sub' not exportable"
        unless grep { $sub eq $_ } qw( render );

      my $caller = caller();

      no strict 'refs';    ## no critic (ProhibitNoStrict)
      local $SIG{__WARN__} = \&Carp::carp;
      *{$caller . q<::> . $sub} = \&{$package . q<::> . $sub};
   } ## end for my $sub (@_)

   return;
} ## end sub import

sub render {               ## no critic (RequireArgUnpacking)
   my $template = shift;
   my (%variables, %params);
   if (@_) {
      %variables = ref($_[0]) ? %{shift @_} : splice @_, 0;
      %params = %{shift @_} if @_;
   }
   return __PACKAGE__->new(%params)->process($template, \%variables);
} ## end sub render

# Object-oriented interface
sub new {                  ## no critic (RequireArgUnpacking)
   my $self = bless {
      start     => '[%',
      stop      => '%]',
      utf8      => 1,
      variables => {},
     },
     shift;
   %{$self} = (%{$self}, @_ == 1 ? %{$_[0]} : @_);
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

sub compile {    ## no critic (RequireArgUnpacking)
   my ($self, undef, %args) = @_;
   my $outcome = $self->_compile_code_text($_[1]);
   return $outcome if $args{no_check};
   return $self->_compile_sub($outcome);
} ## end sub compile

sub compile_as_sub {    ## no critic (RequireArgUnpacking)
   my $self = shift;
   return $self->compile($_[0])->{'sub'};
}

sub _compile_code_text {
   my ($self, $template) = @_;

   my $starter = $self->{start};
   my $stopper = $self->{stop};

   my $compiled = "# line 1 'input'\n";
   $compiled .= "use utf8;\n\n" if $self->{utf8};
   $compiled .= "print {*STDOUT} '';\n\n";
   my $pos     = 0;
   my $line_no = 1;
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
      if ($stop < 0) {    # no matching $stopper, bummer!
         my $section = _extract_section({template => $template}, $line_no);
         croak "unclosed starter '$starter' at line $line_no\n$section";
      }
      my $code = substr $template, $pos, $stop - $pos;

      # Now I can advance the line count considering the $starter too
      $line_no += ($starter =~ tr/\n//);

      if (length $code) {
         if (my $path = _smart_split($code)) {
            $compiled .= _variable($path);
         }
         elsif (my ($scalar) =
            $code =~ m{\A\s* (\$ [[:alpha:]_]\w*) \s*\z}mxs)
         {
            $compiled .=
              "\nprint {*STDOUT} $scalar; ### straight scalar\n\n";
         } ## end elsif (my ($scalar) = $code...)
         elsif (substr($code, 0, 1) eq q<=>) {
            $compiled .= "\n# line $line_no 'template<3,$line_no>'\n"
              . _expression(substr $code, 1);
         }
         else {
            $compiled .=
              "\n# line $line_no 'template<0,$line_no>'\n" . $code;
         }
      } ## end if (length $code)

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
} ## end sub _compile_code_text

sub _V
{    ## no critic (ProhibitUnusedPrivateSubroutines,RequireArgUnpacking)
   my $value = shift;
   for my $chunk (@_) {
      if (ref($value) eq 'HASH') {
         $value = $value->{$chunk};
      }
      elsif (ref($value) eq 'ARRAY') {
         $value = $value->[$chunk];
      }
      else {
         return '';
      }
   } ## end for my $chunk (@_)
   return defined($value) ? $value : '';
} ## end sub _V

sub V  { return '' }
sub A  { return }
sub H  { return }
sub HK { return }
sub HV { return }

sub _compile_sub {
   my ($self, $outcome) = @_;

   my @warnings;
   {
      my $utf8 = $self->{utf8} ? 1 : 0;
      local $SIG{__WARN__} = sub { push @warnings, @_ };
      $outcome->{sub} =
        eval <<"END_OF_CODE";    ## no critic (ProhibitStringyEval)
   sub {
      my \%variables = (\%{\$self->{variables}}, \%{shift || {}});

      no warnings 'redefine';
      local *V = sub {
         my \$path = _smart_split(shift) or return '';
         return _V(\\\%variables, \@\$path);
      };
      local *A = sub {
         my \$v = V(shift) or return;
         return \@\$v;
      };
      local *H = sub {
         my \$v = V(shift) or return;
         return \%\$v;
      };
      local *HK = sub {
         my \$v = V(shift) or return;
         return keys \%\$v;
      };
      local *HV = sub {
         my \$v = V(shift) or return;
         return values \%\$v;
      };
      use warnings 'redefine';

      local *STDOUT;
      open STDOUT, '>', \\my \$___buffer or croak "open(): \$OS_ERROR";
      binmode STDOUT, ':encoding(utf8)' if $utf8;
      my \$___previous_selection = select(STDOUT);
      { # closure to free "my" variables
$outcome->{code_text}
      }
      select(\$___previous_selection);
      close STDOUT;
      if ($utf8) {
         require Encode;
         \$___buffer = Encode::decode(utf8 => \$___buffer);
      }
      return \$___buffer;
   }
END_OF_CODE
      return $outcome if $outcome->{sub};
   }

   ## no critic (RegularExpressions::ProhibitEscapedMetacharacters)
   my $error = $EVAL_ERROR;
   my ($offset, $starter, $line_no) =
     $error =~ m{at\ 'template<(\d+),(\d+)>'\ line\ (\d+)}mxs;
   $line_no -= $offset;
s{at\ 'template<\d+,\d+>'\ line\ (\d+)}{'at line ' . ($1 - $offset)}egmxs
     for @warnings, $error;
   if ($line_no == $starter) {
      s{,\ near\ "\#\ line.*?\n\s+}{, near "}gmxs for @warnings, $error;
   }
   ## use critic

   my $section = _extract_section($outcome, $line_no);
   $error = join '', @warnings, $error, "\n", $section;

   croak $error;
} ## end sub _compile_sub

sub _extract_section {
   my ($hash, $line_no) = @_;
   $line_no--;    # for proper comparison with 0-based array
   my $start = $line_no - ERROR_CONTEXT;
   my $end   = $line_no + ERROR_CONTEXT;

   my @lines = split /\n/mxs, $hash->{template};
   $start = 0       if $start < 0;
   $end   = $#lines if $end > $#lines;
   my $n_chars = length($end + 1);
   return join '', map {
      sprintf "%s%${n_chars}d| %s\n",
        (($_ == $line_no) ? '>>' : '  '), ($_ + 1), $lines[$_];
   } $start .. $end;
} ## end sub _extract_section

sub _simple_text {
   my $text = shift;

   return "print {*STDOUT} '$text';\n\n" if $text !~ /[\n'\\]/mxs;

   $text =~ s/^/ /gmxs;    # indent, trick taken from diff -u
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

sub _smart_split {
   my ($input) = @_;
   $input =~ s{\A\s+|\s+\z}{}gmxs;

   ## no critic (RequireExtendedFormatting,RegularExpressions::RequireLineBoundaryMatching,RegularExpressions::RequireDotMatchAnything)
   my $sq    = qr{(?mxs: ' [^']* ' )};
   my $dq    = qr{(?mxs: " (?:[^\\"] | \\.)* " )};
   my $ud    = qr{(?mxs: \w+ )};
   my $chunk = qr{(?mxs: $sq | $dq | $ud)+};
   ## use critic

   # save and reset current pos() on $input
   my $prepos = pos($input);
   pos($input) = undef;

   my @path;
   push @path, $1    ## no critic (ProhibitCaptureWithoutTest)
     while $input =~ m{\G [.]? ($chunk) }cgmxs;

   # save and restore pos() on $input
   my $postpos = pos($input);
   pos($input) = $prepos;

   return unless defined $postpos;
   return if $postpos != length($input);

   # cleanup @path components
   for my $part (@path) {
      my @subparts;
      while ((pos($part) || 0) < length($part)) {
         if ($part =~ m{\G ($sq) }cgmxs) {
            push @subparts, substr $1, 1, length($1) - 2;
         }
         elsif ($part =~ m{\G ($dq) }cgmxs) {
            my $subpart = substr $1, 1, length($1) - 2;
            $subpart =~ s{\\(.)}{$1}gmxs;
            push @subparts, $subpart;
         }
         elsif ($part =~ m{\G ($ud) }cgmxs) {
            push @subparts, $1;
         }
         else {    # shouldn't happen ever
            return;
         }
      } ## end while ((pos($part) || 0) ...)
      $part = join '', @subparts;
   } ## end for my $part (@path)
   return \@path;
} ## end sub _smart_split

sub _variable {
   my $path = shift;
   my $DQ   = q<">;
   $path = join ', ', map { $DQ . quotemeta($_) . $DQ } @{$path};

   return <<"END_OF_CHUNK";
### Variable from \%variables stash
print {*STDOUT} _V(\\\%variables, $path);

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

} ## end sub _expression

1;
