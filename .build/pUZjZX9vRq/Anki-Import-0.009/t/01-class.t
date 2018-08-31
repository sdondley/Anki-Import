#/usr/bin/env perl
use t::TestUtils;
use Test::More;
use Anki::Import;
use Test::Exception;
use Test::Warnings;










my $tests = 6; # keep on line 17 for ,i (increment and ,d (decrement)
diag( "Running my tests" );

plan tests => $tests;

# create an object
my $obj = '';

dies_ok { anki_import(); } 'dies without file getting passed';
dies_ok { anki_import('askdjfakdewere2332'); } 'dies with bad file name';
lives_ok { anki_import('t/data/source.anki'); } 'lives with good file name';
lives_ok { anki_import('t/data/source.anki', '~', '-vv'); } 'lives with good file name';
lives_ok { anki_import('t/data/source.anki'); } 'lives with good file name';
dies_ok { anki_import('t/data/source2.anki'); } 'dies when notes have different number of fields';
