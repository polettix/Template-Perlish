# vim: filetype=perl :
use strict;
use warnings;

use Test::More;    # tests => 4; # last test to print
use Template::Perlish qw< render >;

{
   my $data = {
      foo => 'bar',
      baz => {
         inner => 'stuff',
         also  => [qw< one array >],
      },
      frotz => {
         one   => 'two',
         three => 'four',
      }
   };

   my @tests = (
      ['[%= V "baz.also.1" %]',               'array',      'V()'],
      ['[%= join("-", A "baz.also") %]',      'one-array',  'A()'],
      ['[%= join("-", sort(HK("baz"))) %]',   'also-inner', 'HK()'],
      ['[%= join("-", sort(HV("frotz"))) %]', 'four-two',   'HV()'],
      [
         '[%= my %h = H "frotz"; join("-", sort(keys(%h))) %]',
         'one-three', 'H()'
      ],
   );

   for my $spec (@tests) {
      my ($template, $expected, $message) = @$spec;
      my $got = render($template, $data);
      is $got, $expected, $message;
   }
}

done_testing();
