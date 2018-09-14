#!/usr/bin/env perl
use Test::More;
use Anki::Import;
use Test::Exception;
use Test::Warnings;
use File::Path;
use File::Spec;









my $tests = 8; # keep on line 17 for ,i (increment and ,d (decrement)
diag( "Running my tests" );

plan tests => $tests;
dies_ok { anki_import(); } 'dies without file getting passed';
dies_ok { anki_import('askdjfakdewere2332'); } 'dies with bad file name';
my $path1 = File::Spec->catfile('t', 'data', 'source.anki' );
my $path2 = File::Spec->catfile( 't', 'data', 'source2.anki' );
my $path3 = File::Spec->catfile( 't', 'data', 'tag_test.anki' );
lives_ok { anki_import($path1); } 'lives with good file name';
lives_ok { anki_import($path1, '-V'); } 'lives with good file n#ame';
lives_ok { anki_import($path1); } 'lives with good file name';
dies_ok { anki_import($path2); } 'dies when notes have different nu#mber of fields';
lives_ok { anki_import($path3, '-V'); } 'lives with good file name';
#lives_ok { anki_import('t/data/cs61.anki', '-V'); } 'lives with good file name';
rmtree 'anki_import_files';
