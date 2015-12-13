# vim: filetype=perl :
use strict;
use warnings;

use Test::More;    # tests => 4; # last test to print
use Template::Perlish qw< traverse >;

my $hash = {
   one => 'ONE',
   two => 'TWO',
   three => 'THREE',
   4 => 'FOUR, but in digits',
};

my $array = [ 0..3, 'four' ];

my $data = {
   hash => $hash,
   array => $array,
   complex_hash => {
      hash => $hash,
      array => $array,
      something => { more => 1 },
      hey => [ qw< you all > ],
   },
   complex_array => [ $hash, $array, { something => 'more' }, [ 'hey' ] ],
};

my @tests = (
   [ { data => $data }, $data, 'root, no ref' ],
   [ { data => $data, path => 'complex_hash.array' }, $array,
      'down in hashes' ],
   [ { data => $data, path => 'complex_hash.array.4' }, 'four',
      'down in hashes and array' ],
   [ { data => $data, path => 'complex_array.0' }, $hash,
      'down in hash and array' ],
   [ { data => $data, path => 'complex_hash.array.4' }, 'four',
      'down in hashes and array' ],
   [ { data => $data, path => 'complex_hash.hash.4' },
      'FOUR, but in digits', 'down in hashes to the leaf' ],
   [ { data => $data, path => ['hash', {4 => 1}] },
      'FOUR, but in digits', 'down in hashes, with constraint' ],
   [ { data => $data, path => ['hash', [4]] },
      '', 'down in hashes, failed constraint' ],
   [ { data => $data, path => 'inexistent' }, '', 'inexistent key' ],

   [ { data => $data, ref => 1 }, \$data, 'root, ref' ],
   [ { data => $data, path => 'complex_hash.array', ref => 1 }, \$array,
      'down in hashes, ref' ],
   [ { data => $data, path => 'complex_array.0', ref => 1 }, \$hash,
      'down in hash and array, ref' ],
   [ { data => $data, path => ['complex_hash', {array => 1}], ref => 1 },
      \$array, 'down in hashes, with constraint, ref' ],
   [ { data => $data, path => 'inexistent', ref => 1},
      sub { \($data->{inexistent}) }, 'inexistent key, ref' ],
   [ { data => $data, path => ['inexistent', {4 => 1} ], ref => 1},
      sub { \($data->{inexistent}{4}) }, 'inexistent key 2, ref' ],
   [ { data => $data, path => ['inexistent', {4 => 1}, 2 ]},
      '', 'yet to auto-vivify index has no value now' ],
   [ { data => $data, path => ['inexistent', {4 => 1}, 2 ], ref => 1},
      sub { \($data->{inexistent}{4}[2] = 42) }, 'inexistent index, ref' ],
   [ { data => $data, path => ['inexistent', {4 => 1}, 2 ]},
      42, 'auto-vivified index has right value now' ],
);

for my $spec (@tests) {
   my ($inputs, $expected, $message) = @$spec;
   my $got = traverse($inputs);
   $expected = $expected->() if ref($expected) eq 'CODE';
   if (defined $expected) {
      is_deeply $got, $expected, $message;
   }
   else {
      ok((!defined $got), $message)
         or diag("got [$got] instead!");
   }
} ## end for my $spec (@tests)

done_testing(scalar @tests);
