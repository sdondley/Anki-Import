#!/usr/bin/env perl
use Test::More;
use Anki::Import;
use Test::Exception;
use Test::Warnings;
use Test::Output;
use Anki::Import;
use Log::Log4perl::Shortcuts qw(:all);
use Data::Dumper qw(Dumper);
use Path::Tiny;
use File::Path;





my $tests = 9; # keep on line 17 for ,i (increment and ,d (decrement)
diag( "Running my tests" );

plan tests => $tests;

my $data = get_data('code_with_blank_lines', 'basic');
print Dumper $data;

is (mcount("\t"), 1, 'got expected number of tabs');
is (mcount("\n"), 0, 'got expected number of newlines');
is (mcount("^<div"), 1, 'begins with div tags');
is (mcount("/div>\t"), 1, 'div tag closed before tab');
is (mcount("\tAnswer\$"), 1, 'answer properly formatted');
is (mcount(">Line 1<br><br>"), 1, 'line 1 properly formatted');
is (mcount("><br>Line 2<br><br>"), 1, 'line 2 properly formatted');
is (mcount(">Line 3</div>"), 1, 'line 3 does not end in <br>');

rmtree 't/data/anki_import_files';

sub get_data {
  my $file = shift;
  my $type = shift;
  anki_import("t/data/$file.anki", 't/data', '-V');
  $data = path("t/data/anki_import_files/${type}_notes_import.txt")->slurp_utf8;
}

sub mcount {
  my $regex_str = shift;
  my @matches = $data =~ /$regex_str/g;
  my $matches = @matches;

  return $matches;
}
