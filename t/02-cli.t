#/usr/bin/env perl
use Test::More;
use Anki::Import;
use Test::Exception;
use Test::Warnings;
use Test::Output;
use Data::Dumper qw(Dumper);
use File::Path;








my $tests = 3; # keep on line 17 for ,i (increment and ,d (decrement)
diag( "Running my tests" );

plan tests => $tests;

stderr_like { `bin/anki_import` } qr/[FATAL].*No file/, 'dies without file';
stderr_like { `bin/anki_import blah` } qr/[FATAL].*does not exist/, 'dies with bad file';
lives_ok { `bin/anki_import t/data/source.anki` } 'can process good file';

rmtree 'anki_import_files';
