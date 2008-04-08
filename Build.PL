use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Template::Perlish',
    license             => 'perl',
    dist_author         => 'Flavio Poletti <flavio [at] polettix [dot] it>',
    dist_version_from   => 'lib/Template/Perlish.pm',
    requires => {
        'perl'       => '5.8.0',
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Template-Perlish-*' ],
);

$builder->create_build_script();
