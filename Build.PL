use strict;
use warnings;
use Module::Build;
use 5.010;

my $builder = Module::Build->new(
    module_name       => 'App-YesssSpendings',
    license           => 'perl',
    dist_author       => 'Thomas Klausner',
    dist_version_from => 'lib/App/YesssSpendings.pm',
    build_requires    => { 'Test::More' => 0, },
    requires          => {
        'perl'               => '5.010',
        'WWW::Mechanize'     => 0,
        'DateTime'           => 0,
        'HTML::TableExtract' => 0,
        'Moose'              => 0,
    },
    add_to_cleanup       => ['App-YesssSpendings-*'],
    create_makefile_pl   => 'passthrough',
    recursive_test_files => 1,
);

$builder->create_build_script();
