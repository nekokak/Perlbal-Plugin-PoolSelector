use inc::Module::Install;
name 'Perlbal-Plugin-PoolSelector';
all_from 'lib/Perlbal/Plugin/PoolSelector.pm';

requires 'Perlbal';
requires 'URI::Escape';

build_requires 'Test::More';

use_test_base;
auto_include;
auto_set_repository;
WriteAll;

