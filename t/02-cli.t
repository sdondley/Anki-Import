#!/usr/bin/env perl
use Test::More;
use Anki::Import;
use Test::Exception;
use Test::Warnings;
use Test::Output;
use Data::Dumper qw(Dumper);
use File::Spec;
use File::Path;








my $tests = 4; # keep on line 17 for ,i (increment and ,d (decrement)
diag( "Running my tests" );

plan tests => $tests;

my $cmd = File::Spec->catfile('bin', 'anki_import');
stderr_like { `$cmd` } qr/usage: anki_import FILE/, 'dies without file';
$cmd = File::Spec->catfile('bin', 'anki_import');
stderr_like { `$cmd blasdfah` } qr/[FATAL].*does not exist/, 'dies with bad file';
$cmd = File::Spec->catfile('bin', 'anki_import');
my $path = File::Spec->catfile('t', 'data' , 'source.anki');
lives_ok { `$cmd $path` } 'can process good file';
#lives_ok { `bin/anki_import t/data/distzilla.anki -V` } 'can process good file';

rmtree 'anki_import_files';
