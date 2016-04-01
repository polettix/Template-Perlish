# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 19; # last test to print
use Template::Perlish qw< traverse >;

my $hash = {
   one   => 'ONE',
   two   => 'TWO',
   three => 'THREE',
   4     => 'FOUR, but in digits',
};

my $array = [0 .. 3, 'four'];

my $data = {
   hash         => $hash,
   array        => $array,
   complex_hash => {
      hash      => $hash,
      array     => $array,
      something => {more => 1},
      hey       => [qw< you all >],
   },
   complex_array => [$hash, $array, {something => 'more'}, ['hey']],
};
my $ref = \$data;

my @tests = (
   [[$data], $data, 'root, no ref'],
   [[$data, 'complex_hash.array'],   $array, 'down in hashes'],
   [[$data, 'complex_hash.array.4'], 'four', 'down in hashes and array'],
   [[$data, 'complex_array.0'],      $hash,  'down in hash and array'],
   [[$data, 'complex_hash.array.4'], 'four', 'down in hashes and array'],
   [
      [$data, 'complex_hash.hash.4'],
      'FOUR, but in digits',
      'down in hashes to the leaf'
   ],
   [
      [$data, ['hash', {4 => 1}]],
      'FOUR, but in digits',
      'down in hashes, with constraint'
   ],
   [[$data, ['hash', [4]]], '', 'down in hashes, failed constraint'],
   [[$data, 'inexistent'], '', 'inexistent key'],

   [[$ref], $ref, 'root, ref'],
   [[$ref, 'complex_hash.array'], \$array, 'down in hashes, ref'],
   [[$ref, 'complex_array.0'],    \$hash,  'down in hash and array, ref'],
   [
      [$ref, ['complex_hash', {array => 1}]],
      \$array,
      'down in hashes, with constraint, ref'
   ],
   [
      [$ref, 'inexistent'],
      sub { \($data->{inexistent}) },
      'inexistent key, ref'
   ],
   [
      [$ref, ['inexistent', {4 => 1}]],
      sub { \($data->{inexistent}{4}) },
      'inexistent key 2, ref'
   ],
   [
      [$data, ['inexistent', {4 => 1}, 2]],
      '',
      'yet to auto-vivify index has no value now'
   ],
   [
      [$ref, ['inexistent', {4 => 1}, 2]],
      sub { \($data->{inexistent}{4}[2] = 42) },
      'inexistent index, ref'
   ],
   [
      [$data, ['inexistent', {4 => 1}, 2]],
      42,
      'auto-vivified index has right value now'
   ],
);

for my $spec (@tests) {
   my ($inputs, $expected, $message) = @$spec;
   my $got = traverse(@$inputs);
   $expected = $expected->() if ref($expected) eq 'CODE';
   if (defined $expected) {
      is_deeply $got, $expected, $message;
   }
   else {
      ok((!defined $got), $message)
        or diag("got [$got] instead!");
   }
} ## end for my $spec (@tests)

{
   use Data::Dumper;
   my $var;
   my $ref_to_value = traverse(\$var, "some.0.'comp-lex'.path");
   $$ref_to_value = 42; # note double sigil for indirection
   is $var->{some}[0]{'comp-lex'}{path}, 42, 'starting from undef var';
}

done_testing(1 + scalar @tests);
