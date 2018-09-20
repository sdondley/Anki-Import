#!/usr/bin/env perl
use Test::More;
use Anki::Import;
use Test::Warnings;
use File::Spec;
use File::Path;

my $tests = 14; # keep on line 17 for ,i (increment and ,d (decrement)
diag( "Running my tests" );

plan tests => $tests;

my $data = get_data('code_with_blank_lines', 'basic');

is (mcount("\t"), 1, 'got expected number of tabs');
is (mcount("\n"), 0, 'got expected number of newlines');
is (mcount("^<div"), 1, 'begins with div tags');
is (mcount("/div>\t"), 1, 'div tag closed before tab');
is (mcount("\tAnswer\$"), 1, 'answer properly formatted');
is (mcount(">Line 1<br><br>"), 1, 'line 1 properly formatted');
is (mcount("><br>Line 2<br><br>"), 1, 'line 2 properly formatted');
is (mcount(">Line 3</div>"), 1, 'line 3 does not end in <br>');

$data = get_data('escape_angle_brackets', 'basic');

is (mcount("&lt;"), 4, 'got expected number of html entities');
is ($data =~ /with &lt;angle/, 1, 'first angle bracket replaced');
is ($data =~ /one &lt;angle/, 1, 'second angle bracket replaced');
is ($data =~ /more &lt;of/, 1, 'third angle bracket replaced');
is ($data =~ /of &lt;them/, 1, 'last angle bracket replaced');

use Data::Dumper qw(Dumper);

print Dumper $data;



my $path = File::Spec->catfile('t', 'data', 'anki_import_files');
rmtree $path;

sub get_data {
  my $file = shift;
  my $type = shift;
  my $path1 = File::Spec->catfile('t', 'data', "$file.anki");
  my $path2 = File::Spec->catfile('t', 'data');
  anki_import($path1, $path2, '-V');
  my $path3 = File::Spec->catfile('t', 'data', 'anki_import_files', "${type}_notes_import.txt");
  open (my $data_file, "<:encoding(UTF-8)", $path3) or die "Can't open '$path3' for reading: $!";
  my $content;
  { local $/; $content = <$data_file>; }
  close $file;
  return $content;
}

sub mcount {
  my $regex_str = shift;
  my @matches = $data =~ /$regex_str/g;
  my $matches = @matches;

  return $matches;
}
