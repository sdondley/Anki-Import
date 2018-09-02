package Anki::Import ;

use strict;
use warnings;
use Cwd;
use Path::Tiny;
use Getopt::Args;
use Log::Log4perl::Shortcuts qw(:all);
use Exporter qw(import);
our @EXPORT = qw(anki_import);

# set up variables
my @lines;                # lines from source file
my $line_count = 0;       # count processed lines to give more helpful error msg
my $cline      = '';      # current line getting processed
my $lline      = '';      # last (previous) line processed
my $ntype      = 'Basic'; # default note type
my %notes      = ();      # data structure for storing notes
my @autotags   = ();      # for storing automated tags

change_config_file('anki-import.cfg', __PACKAGE__);

# argument processing
arg parent_dir => (
  isa => 'Str',
  default => cwd,
  comment => 'optional directory to save output files, default to current directory',
);
opt verbose => (
  isa => 'Bool',
  alias => 'v',
  comment => 'provide details on progress of Anki::Import'
);
opt vverbose => (
  isa => 'Bool',
  alias => 'vv',
  comment => 'verbose information plus debug info'
);

# start here
sub anki_import {
  my $file = shift;
  logf('No file passed to Anki::Import. Aborting.') if !$file;

  my $args = optargs( @_ );

  # set log level as appropriate
  if ($args->{verbose}) {
    set_log_level('info');
  } elsif ($args->{vverbose}) {
    set_log_level('debug');
  } else {
    set_log_level('error');
  }
  logi('Log level set');


  # get and load the source file
  logi('Loading file');
  my $path  = path($file);
  if (!path($file)->exists) {
    logf("Source file named '$file' does not exist.");
  };
  @lines = $path->lines_utf8;

  # pad data with a blank line to make it easier to process
  push @lines, '';

  # do the stuff we came here for
  validate_src_file();
  logd(\%notes);
  generate_importable_files($args->{parent_dir});
  # fin
}

# functions for first pass parsing of source data
sub validate_src_file {
  logi('Validating source file');

  # throw error if file is empty
  logf('Source data file is empty.') if !$lines[0];

  # outer loop for parsing notes
  my %fields;  # keeps track of number of fields for each type of note
  while (next_line()) {

    # ignore blank lines
    next if ($cline =~ /^$|^\s+$/);

    if ($cline =~ /^#\s*(\S+)/) {
      $ntype = $1;
      logi("Found note type");
      logd($ntype);
      next;
    }

    logi('Processing new note');
    # get the note
    my $note = slurp_note();
    logd($note);

    logi('Checking number of note fields');
    # validaate that notes of the same type have the same number of fields
    if (my $number_of_fields = $fields{$ntype}) {
      if (scalar (@$note) != $number_of_fields) {
        my $field_count = scalar(@$note);
        logf("A(n) $ntype note ending on line $line_count"
        . " has $field_count fields, a different amount than previous '$ntype' note types."
        . " Notes of the same note type must have the same number of fields. One common reason"
        . " for this error is that you did not indicate that you wanted to leave a field blank. To leave a field blank,"
        . " place a single '`' (backtick) on the line by itself in the source file. You may also"
        . " have failed to separate notes with two or more blank lines."
        . " Check your source file to ensure it is properly formatted.\n\n\tRefer to the"
        . " Anki::Import documentation for more help with formatting your source file."
        );
      }
    } else {
      $fields{$ntype} = scalar @$note;
    }

    logi('Storing note');
    store_note($note);
  }

}

sub slurp_note {
  my @current_field;
  my @note;
  push @current_field, $cline;

  # loop over lines in the note
  while (next_line()) {
    if ($cline =~ /^$|^\s+$/) {
      my @all_fields = @current_field;
      push (@note, \@all_fields) if @current_field;
      @current_field = ();
      if ($lline =~ /^$|^\s+$/) {
        last;
      }
    } else {
      push @current_field, $cline;
    }
  }
  return \@note;
}

sub store_note {
  my $note = shift;
  logd($note);

  if ($notes{$ntype}) {
    push @{$notes{$ntype}}, $note;
  } else {
    $notes{$ntype} = [$note];
  }
}

sub next_line {
  return 0 if !@lines; # last line in file is always blank
  $lline = $cline;
  $cline = (shift @lines || '');
  chomp $cline;
  ++$line_count;
}


# functions for second pass parsing and formatting of source data
# and creation of import files
sub generate_importable_files {
  my $pd = shift;
  logi('Generating files for import');

  # loop over note types
  foreach my $ntype (keys %notes) {
    logi('Looping over note type');
    my $file = '';

    # loop over notes
    logi('Formatting notes for output');
    foreach my $note (@{$notes{$ntype}}) {
      $file .= process_note($note);
    }
    chomp $file;
    logd($file);

    # write our file out
    logi('Writing notes out to file');
    my $out_path = path($pd, "anki_import_files/${ntype}_notes_import.txt")->touchpath;
    $out_path->spew([$file]);
  }
}

sub process_note {
  my $note = shift;

  my $new_autotags = 0;
  my $out = '';
  # loop over fields
  foreach my $field (@$note) {
    my $in_code = 0;   # tracks if we are preserving whitespace
    my $field_out = '';
    my $last_field = '';

    # loop over lines in field
    foreach my $line (@$field) {

      # detect automated tags
      logd($line);
      if ($line =~ /^\^\s*$/) {
        $field_out =~ s/\s*$//;
        @autotags = split (/,\s*/, $field_out);
        $new_autotags = 1;
        next;
      }

      if ($line =~ /^`\s*$/ && !$in_code) {
        next;
      }
      if ($line =~ /^`{3,3}$/ && !$in_code) {
        $in_code = 1;
        if ($field_out) {
          $field_out .= '<br><br>';
        }
        $field_out .= '<div style="text-align: left; font-family: courier; white-space: pre;">';
        next;
      }

      # exit whitespace preservation mode
      if ($line =~ /^`{3,3}$/ && $in_code) {
        $field_out .= "</div><br><br>";
        $in_code = 0;
        next;
      }
      if ($in_code) {
        # escape characters in preserved text
        $line =~ s/(?<!\\)`/\\`/g;
        $line =~ s/(?<!\\)\*/\\*/g;
        $line =~ s/(?<!\\)%/\\%/g;
        $field_out .= $line . "<br>";
      } else {
        $field_out .= "$line ";
      }
    }
    # handle formatting codes in text, preserve escaped characters

    # backticked characters
    $field_out =~ s/(?<!\\)`(.*?)`/<span style="font-family: courier; weight: bold;">$1<\/span>/gm;
    $field_out =~ s/\\`/`/g;

    # bold
    $field_out =~ s/(?<!\\)\*(.*?)\*/<span style="weight: bold;">$1<\/span>/gm;
    $field_out =~ s/\\\*/*/g;

    # unordered lists
    $field_out =~ s'(?<!\\)%(.*?)%'"<ul><li>" . join ("</li><li>", (split (/,\s*/, $1))) . "</li><\/ul>"'gme;
    $field_out =~ s/\\%/%/g;

    $field_out .= "\t";
    $out .= $field_out;
  }

  # clean up extraneous characters at the end of the line
  $out =~ s/ *\t$|\t$|(<br>)+\t$//;

  # handle autotagging TODO: Ugly, needs cleanup
  if (@autotags && !$new_autotags) {
    $note->[-1][0] = '' if $note->[-1][0] =~ /^`\s*$/;
    my @note_tags = split (/,\s*/, $note->[-1][0]);
    logd(\@note_tags);
    my @new_tags = ();
    foreach my $note_tag (@note_tags) {
      my $in_autotags = grep { $_ eq $note_tag } @autotags;
      push @new_tags, $note_tag unless $in_autotags;
    }
    foreach my $autotag (@autotags) {
      my $discard_autotag = grep { $_ eq $autotag } @note_tags;
      push @new_tags, $autotag if !$discard_autotag;
    }
    my @fields = split (/\t/, $out);
    pop @fields if @note_tags;
    push @fields, join (',', @new_tags);
    $out = join "\t", @fields;
  }
  $new_autotags = 0;

  # create cloze fields
  my $cloze_count = 1;
  # TODO: should probably handle escaped braces just in case
  while ($out =~ /\{\{\{(.*?)}}}/) {
    $out =~ s/\{\{\{(.*?)}}}/{{c${cloze_count}::$1}}/s;
    $cloze_count++;
  }

  $out .= "\n";
}


1; # Magic true value
# ABSTRACT: Anki note generation made easy.

__END__

=head1 OVERVIEW

Efficiently generate formatted Anki notes with your
text editor for easy import into Anki.

=head1 SYNOPSIS

    # Step 1: Create the source file

    # Step 2: Run the anki_import command
      supplied by this module...

    # ...from the command line
    anki_import path/to/source_file.txt

    # or

    # ...from within a perl script
    use Anki::Import;
    anki_import('path/to/source_file.txt');

    # Step 3: Import the resultant files into Anki

=head1 DESCRIPTION

Inputting notes into Anki can be a tedious chore. C<Anki::Import> lets you
you generate Anki notes with your favorite text editor (e.g. vim, BBEdit, Atom,
etc.) so you can enter formatted notes into Anki's database more efficiently.

At a minimum, you should have basic familiarity with using your computer's
command line terminal to make use of this program.

=head2 Steps for creating, processing and imorting new notes

=head3 Step 1: Generate the notes with your text editor

First, you create a specially formatted source file which
C<Anki::Import> will process. The source file is a simple text file with
basic formatting rules you must follow.

See the L</General description of the source file> section for details.

=head3 Step 2: Process the notes with C<Anki::Import>

Once the source file is created and saved, run the
C<anki_import> command from the command line or from a script to generate the
import files. This will create a new directory called "anki_import_files"
containing one text file for each of the note types generated by C<Anki::Import>
and which you will import in the next step. By default, the directory is
created in the current directory.

See the L</USAGE> section for more details and options.

=head3 Step 3: Import the processed notes with Anki

In Anki, open the deck you wish to import and hit Ctrl-I or (Cmd-I on a
Mac) to start the import process, navigate to the a file generated by
C<Anki::Import> and select one of them.

Next, check Anki's settings to be sure you are importing notes into the proper
fields, deck and note type. Also ensure you have the "Allow HTML in fields"
option enabled and that you have "Fields separated by: Tab" selected.

Click "Import" and repeat for each note type you are importing.

Consult L<Anki's documentation|https://apps.ankiweb.net/docs/manual.html#importing>
for more details on importing and managing your notes.

=head2 General description of the source file

The source file contains one or more Anki notes. To make importing easier,
each source file should contain notes that will be imported into the same Anki
deck.

=head3 Creating notes and fields in the source file

Each note in the source file contains fields which should correspond to your
existing note types in Anki. Individual notes in the source file are delineated
by two or more blank lines. Fields are separated by a
single blank line. Fields for each note should be in the same order as your
Anki note types to make importing more automatic. All fields must have content
or left intentionally blank.

To create an intionally blank field, add a single '`' (backtick) character on a
line by itself with blank lines before and after the line with the single
backtick.

See the L</Source file example> for more help.

IMPORTANT: Save the source file as a plain text file with UTF-8 encoding. UTF-8
is likely the default encoding method for your editor but check your editor's
settings and documentation for further details.

=head3 Assigning notes to note types

You can indicate which note type a note belongs to by preceding notes with a
C<#note_type> comment at the beginning of a line. You can choose any note type
name you wish but it is recommended that you use note type names similar to
those that exist in your Anki database to make importing the notes easier.

Any notes appearing after a note type comment will be assigned to that note
type until a new note type comment is encountered (see the example in the next
section). If no note types are indicated in your source file, the "Basic"
note type is used.

Note types are used to help C<Anki::Import> ensure other notes of the same type
have the same number of fields. If the notes assigned to a particular note type
do not all have the same number of fields, an error is thrown so be sure each
note has the correct number of fields.

Note: note type sections can be split across the file (i.e. you do not have to
group the notes of a particular note type together).

=head3 Tagging notes

Place your comma seprated lit of tags in the last field. As long as there is
one more field in the source files that fields in the note you are importing
to, Anki will generate tags from the last field.

You can automate tag generation by placing a single '^' (caret) character
on a line by itself immediately after your list of tags. These tags will now
be used for all later notes in the file until they are overridden by a new list
of automated tags. Also any new tags you place at the end of a note will be
added to the list of tags that are automatically generated.

To reset the automated list of tags, place a single '^' (caret) character
in place of the field where your tags will go.

To suppress the application of an automated tag from the list of automated tags
for a particular note, include that tag in the tag field and it will not be
tagged with that term for that one note.

Note: If you use tags on any of your notes in a parcitular note type, you must
use tags on all of your notes or indicate that the tag field should be left
blank with a '`' (backtick) character on a line by itself.

=head3 Applying text formatting to your notes

Learning how to format the source file is key to getting Anki to import your
notes properly and getting the most out of C<Anki::Import>.

Following a few simple rules, you can assign notes to a note type, preserve
whitespace in fields, create bold text, create blank lines in your fields,
add tags, create cloze deletions, indicate which fields are blank and
generate simple lists. Study the example below for details.

Note: Lines containing only whitespace characters are treated as blank lines.

=head4 Source file example

Below is an example of how to format a source data file. Note that the column on
the right containing comments for this example are not permitted in an actual
source data file.

    # Basic                              # Any notes below here to the next
                                         # note type comment are assigned to
                                         # the 'Basic' note type

                                         # You can have blank lines between the
                                         # note type comment and the next
                                         # question.

    What is the first day of the week?   # Question 1, Field 1
                                         # Blank line here indicates a new field.
    Monday.                              # Question 1, Field 2

                                         # Add two or more blank lines between
                                           questions



    How many days of the week are there? # Question 2, Field 1

    Our caldendar                        # Question 2, Field 2
    has seven days                       # Answers can run
    in a week                            # across one or more lines but
                                         # will be imported as a single
                                         # line into Anki.



    # less_basic                         # New note type called "less_basic"
                                         # with 3 fields
    What is the third day of week?       # Question 3, Field 1

    Wednesday                            # Question 3, Field 2

    Wed.                                 # Question 3, Field 3

    your_tags, go_here                   # We set up automated tags on this note.
    ^                                    # These tags will be applied to this and
                                         # all future notes unless overridden.


    Put {{{another question}}} here.     # Surround text with 3 braces for a cloze

    Here is an field that has
    `                                    # Insert a blank line into a field
    a blank line in it.                  # with a single backtick character
                                         # surrounded by lines with text.
    go_here                              # The note will *not* be tagged with
                                         # 'go_here' but it will still be
                                         # tagged with 'your_tags' from
                                         # the automated tag list.



    What does this code do?              # Another less_basic question

    ```                                  # Preserve whitespace in a field with 3
                                         # backticks on a single line
    This_is_some_code {
        print 'Whitespace will be        # Whitespace is preserved between the
               preserved';               # sets of triple backticks
    }
    ```                                  # end whitespace preservation

    This is %comma,delimted,text%        # Bullet lists with %item1,item2,item3%

    '                                    # To suppress all tags for a note,
                                         # leave the tag field blank with a
                                         # backtick.


    Final question                       # Field 1

    `                                    # Field 2 is blank.

    This is *in bold*                    # Field 3 has bold words, followed by a
    `                                    # blank line, followed by
    %an,unordered,list%                  # an ordered list.

    new_tags, more_new_tags              # This and future notes will use these
    ^                                    # newer automated tags.

=head1 USAGE

C<anki_import> can be run from the command line or from within another perl
script. It behaves the same way in both environments.

=head2 Command line usage

The C<Anki::Import> module installs the C<anki_import> command line command
for generating import files which is used as follow:

    anki_import source_file [parent_dir] [verbosity_level]

    B<Example:> anki_import notes.text /home/me --verbose

C<anki_import> processes the source file and generates files to be imported into
Anki, one file for each note type. These files are placed in a directory called
C<anki_import_files>. This directory is placed in the current working directory
by default.

Note: Previously generated files of a particular note type will be
overwritten by this command without warning.

B<C<parent_dir>> is an optional argument containing the path you want C<Anki::Import>
to save the files for output. You may use C<~> (tilde) to represent the home
directory for the current user.

B<C<$verbosity>> can be set to either C<--verbose> (C<-v>) or C<--vverbose> (C<-vv>)
for verbosity and maximum verbosity, respectively.

=head2 From a script

Invoking the C<anki_import> function mirrors the arguments used from the
command line:

=method anki_import($source_file, [$parent_dir], [$verbosity]);

Usage in a script is the same as for the command line except that the arguments
must be enclosed in quotes.

    Example:

    anki_import('script_file.txt', '/home/me', '--verbose');

See the L</Command line usage> for more details on the optional arguments.

=head1 INSTALLATION

C<Anki::Import> is written in the Perl programming langauge. Therefore, you must
have the Perl installed on your system. MacOS and *nix machines will have
Perl already installed but the Windows operating system does not
come pre-installed with Perl and so you may have to install it first before you
can use C<Anki::Import>.

If you are unsure if you have Perl installed, open a command prompt and type in:

    perl -v

If Perl is installed, it will report the version of Perl on your machine and
other information. If Perl is not installed, you will get a "not recognized"
error on Windows.

=head2 Installing Strawberry Perl on Windows

If you are on Windows and you do not have Perl installed, you can download a
version of Perl called "Strawberry Perl" from the
L<Strawberry Perl website|http://strawberryperl.com/>. Be sure to install the
proper version (64 or 32 bit).

Once installed successfully, see the next section for downloading and installing
C<Anki::Import>.

=head2 Installing Anki::Import with C<cpanm>

C<Anki::Import> is easy to install if you have a Perl module called
L<App::cpanimus> installed. This module provides a command, C<cpanm>, to easily
downloading and installing modules from the Perl module repository called
B<CPAN>. Simply run this command from the command line to install
C<Anki::Import>:

    cpanm Anki::Import

Strawberry Perl for Windows has the C<cpanm> already installed.

=head2 Installing Anki::Import without C<cpanm>

If you do not have the C<cpan> command on your computer, you will need to use
either the older CPAN shell method of installatoin or, as a last resort, perform
manual installation. Refer to the
C<Anki::Import> L<INSTALL file|https://metacpan.org/source/STEVIED/Anki-Import-0.012/INSTALL>
for further details on these installation methods.

=head1 SEE ALSO

=head2 Development status

This module is currently in the beta stages and is actively supported and
maintained. Suggestions for improvement are welcome. There are likely bugs
with the text formatting in certain edge cases but it should work well for
normal, intended use.

L<Anki documentation|https://apps.ankiweb.net/docs/manual.html>
