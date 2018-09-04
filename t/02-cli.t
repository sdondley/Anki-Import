#/usr/bin/env perl
use Test::More;
use Anki::Import;
use Test::Exception;
use Test::Warnings;
use Test::Output;
use Log::Log4perl::Shortcuts qw(:all);
use Data::Dumper qw(Dumper);
use File::Path;








my $tests = 4; # keep on line 17 for ,i (increment and ,d (decrement)
diag( "Running my tests" );

plan tests => $tests;
set_log_config('test.cfg', 'Anki::Import');

stderr_like { `bin/anki_import` } qr/usage: anki_import FILE/, 'dies without file';
stderr_like { `bin/anki_import blasdfah` } qr/[FATAL].*does not exist/, 'dies with bad file';
lives_ok { `bin/anki_import t/data/source.anki` } 'can process good file';
#lives_ok { `bin/anki_import t/data/distzilla.anki -V` } 'can process good file';

rmtree 'anki_import_files';
