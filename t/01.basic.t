# vim: filetype=perl :
use strict;
use warnings;

#use Test::More tests => 1; # last test to print
use Test::More 'no_plan';    # substitute with previous line when done

BEGIN {
   use_ok('Template::Perlish');
}

my $tt = Template::Perlish->new();
ok($tt, 'object created');
can_ok($tt, qw( get_start get_stop set_start set_stop process ),);
is($tt->get_start(), '[%', 'block starter default');
is($tt->get_stop(),  '%]', 'stop default');

{
   my $template = <<END_OF_TEMPLATE;
This is a simple template with nothing really interesting.

Not even a variable.
END_OF_TEMPLATE
   my $processed = $tt->process($template);
   is($processed, $template, 'simple template');
}
{
   my $template = <<END_OF_TEMPLATE;
This is a simple template with nothing really interesting.

Not even a variable.
END_OF_TEMPLATE
   my $processed = $tt->process($template);
   is($processed, $template, 'simple template, again');
}
{
   my $template = <<END_OF_TEMPLATE;
This is a simple template with nothing really interesting.
[% 
   print "ciao";
%]
At least a block
END_OF_TEMPLATE
   my $result = <<END_OF_TEMPLATE;
This is a simple template with nothing really interesting.
ciao
At least a block
END_OF_TEMPLATE
   my $processed = $tt->process($template);
   is($processed, $result, 'simple template with a block');
}
{
   my $template = <<END_OF_TEMPLATE;
This is a simple template with nothing really interesting.
[% ciao %]
At least a block
END_OF_TEMPLATE
   my $result = <<END_OF_TEMPLATE;
This is a simple template with nothing really interesting.
a tutti
At least a block
END_OF_TEMPLATE
   my $processed = $tt->process($template, {ciao => 'a tutti'});
   is($processed, $result, 'simple template with a variable');
}
