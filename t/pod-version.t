# vim: filetype=perl :

use Test::More;

plan skip_all => "Test::Pod - AUTHOR_TESTING not set"
  unless $ENV{AUTHOR_TESTING};
plan tests => 1;

{
   require Template::Perlish;
   (my $filename = $INC{'Template/Perlish.pm'}) =~ s{pm$}{pod};

   open my $fh, '<', $filename
     or BAIL_OUT "can't open '$filename'";
   binmode $fh, ':raw';
   local $/;
   my $module_text = <$fh>;
   my ($pod_version) = $module_text =~ m{
      ^This\ document\ describes\ Template::Perlish\ version\ (.*?).$
   }mxs;
   is $pod_version, $Template::Perlish::VERSION, 'version in POD';
}
