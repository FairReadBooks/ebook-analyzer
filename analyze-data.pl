#!/usr/bin/env perl
#
# (C) 2016-2018 Norbert Preining
# Licensed under GPL version 3 or higher
#
# Usage
# - put core overlap files into core-lists/Core1.txt ... Core4.txt
#   (directory name can be changed with --corpusdir)
# - put cleaned up files into text-reduced/NNNNN.txt
#   (directory name can be changed with --reduced-txtdir)
# - call
#     perl analyze-data.pl --ids=NNNNN,NNNNN,NNNNN[,...]
#   to obtain out.csv with entries for each id

use v5.12;
use Text::Iconv;
use Text::CSV;
use Spreadsheet::XLSX;
use Term::ProgressBar::Quiet;
use Lingua::EN::Fathom;
use Getopt::Long;

## configuration
my $redtxtdir = "text-reduced";
my $coreloc   = "core-lists";

# output
my $csvout    = "out.csv";

#
my $opt_help = 0;
my $opt_onlyread = 0;
my @ids;

GetOptions(
 "reduced-txtdir=s" => \$redtxtdir,
 "corpusdir=s" => \$coreloc,
 "csvout=s"    => \$csvout,
 "ids=i"       => \@ids,
 "help|h|?"    => \$opt_help) or pod2usage(1);

pod2usage("-exitstatus" => 0, "-verbose" => 2) if $opt_help;

@ids = split(/,/,join(',',@ids));

# read and parsed data
my %data;

# storage for core corpus
my %core;

exit (&main());


# from here on only subroutines

sub main {
  check_presence_of_files();
  read_all_core();
  text_analyze_all();
  shipout_csv($csvout);
}


sub slurp_file {
  my $file = shift;
  my $file_data = do {
    local $/ = undef;
    open my $fh, "<", $file || die "open($file) failed: $!";
    <$fh>;
  };
  return($file_data);
}

sub myround {
  my $f = shift;
  return (int($f * 100) / 100);
}

##############################################################
#
# TEXT ANALYZER
#
##############################################################
sub text_analyze_all {
  my @keys = (@ids ? @ids : keys %data );
  my $progress = Term::ProgressBar::Quiet->new(
    { name => 'analyzing readability and overlap', count => scalar(@keys), ETA => 'linear' } );
  my $i = 0;
  for my $id (@keys) {
    my $f = "$redtxtdir/$id.txt";
    if (-r $f) {
	  my $fcontent = slurp_file($f);
      my $text = Lingua::EN::Fathom->new();
      $text->analyse_file($f);
      # round to two position
      $data{$id}{'fog'} = myround($text->fog);
      $data{$id}{'flesch'} = myround($text->flesch);
      $data{$id}{'kincaid'} = myround($text->kincaid);
      #
      # now for the readability
      my %val = analyze_core_overlap(\$fcontent);
      $data{$id}{'total'} = $val{'total'};
      $data{$id}{'core1'} = $val{1};
      $data{$id}{'core2'} = $val{2};
      $data{$id}{'core3'} = $val{3};
      $data{$id}{'core4'} = $val{4};
    } else {
      # warning already given
      # printf STDERR "Warning: no reduced text file for $id.\n";
    }
    $progress->update( ++$i );
  }
  $progress->message('All done');
}

#######################################################
#
# OUTPUT FUNCTION
#
#######################################################
sub shipout_csv {
  my ($csv) = @_;
  open my $fhcsv, ">:encoding(utf8)", $csv or die "error opening $csv: $!";
  my $c = Text::CSV->new ( { binary => 1 } )
    or die "Cannot use CSV: ".Text::CSV->error_diag ();
  my @row;
  push @row, qw /id_gutenberg fog flesch kincaid
    core1 core1per core2 core2per core3 core3per core4 core4per total_token/;
  $c->print($fhcsv, \@row); printf $fhcsv "\n";
  my @keys = (@ids ? @ids : keys %data );
  for my $id (sort { $a <=> $b } @keys ) {
    my $fog = ( $data{$id}{'fog'} ? $data{$id}{'fog'} : 0);
    my $flesch = ( $data{$id}{'flesch'} ? $data{$id}{'flesch'} : 0);
    my $kincaid = ( $data{$id}{'kincaid'} ? $data{$id}{'kincaid'} : 0);
    #
    my $total = ( $data{$id}{'total'} ? $data{$id}{'total'} : 0 );
    my $core1nr = ( $data{$id}{'core1'} ? $data{$id}{'core1'} : 0 );
    my $core2nr = ( $data{$id}{'core2'} ? $data{$id}{'core2'} : 0 );
    my $core3nr = ( $data{$id}{'core3'} ? $data{$id}{'core3'} : 0 );
    my $core4nr = ( $data{$id}{'core4'} ? $data{$id}{'core4'} : 0 );
    my ($core1per, $core2per, $core3per, $core4per);
    if ($total > 0) {
      $core1per = myround( (100 * $core1nr) / $total );
      $core2per = myround( (100 * $core2nr) / $total );
      $core3per = myround( (100 * $core3nr) / $total );
      $core4per = myround( (100 * $core4nr) / $total );
    } else {
      $core1per = 0;
      $core2per = 0;
      $core3per = 0;
      $core4per = 0;
    }
    my @row;
    push @row, $id, $fog, $flesch, $kincaid,
      $core1nr, $core1per, $core2nr, $core2per,
      $core3nr, $core3per, $core4nr, $core4per,
      $total;
    $c->print($fhcsv, \@row);
    printf $fhcsv "\n";
  }
  close($fhcsv) or warn("Cannot close $csv: $!");
}

########################################
#
# Overlap with core corpus support function
#
#########################################
sub read_all_core {
  for my $i (1..4) {
    read_core($i);
  }
}

sub read_core {
  my $nr = shift;
  my $f = "$coreloc/Core$nr.txt";
  open my $fh, "<:encoding(utf8)", $f or die "error opening $f: $!";
  while (<$fh>) {
    chomp;
    s/\r$//;
    s/^\s*//;
    next if m/^\s*$/;
    $core{$nr}{$_} = 1;
  }
  close $fh or warn "cannot close $f: $!";
}

sub analyze_core_overlap {
  my $reffcontent = shift;
  my $fcontent = ${$reffcontent};
  my $nr = 0;
  my %c;
  my @cores = keys %core;
  # the following method agrees with AntProfiler
  # - split after not-word chars, ', and _
  # - remove numbers
  # - remove empty words
  my @words = split(/[\W'_]/, $fcontent);
  for my $w (@words) {
    # don't count numbers
    next if ($w =~ m/^\d*$/);
    # remove empty words
    next if ($w =~ m/^\s*$/);
    # make upper case
    $w = uc($w);
    # remove all fragments like 'll 't 's
    next if ($w =~ m/^'/);
    $nr++;
    #print "checking for $w in cores ...\n";
    my $found = 0;
    for my $i (@cores) {
      if ($core{$i}{$w}) {
        # note that ++ on an undefined value sets it to 1!
        $c{$i}++;
        $found = 1;
        # WARNING
        # we assume NO OVERLAP in the core files!!!
        # this is currently the case!
        last;
      }
      # not found tokens are counted in slot 0
    }
    $c{0}++ if (!$found);
  }
  $c{'total'} = $nr;
  return(%c);
}

sub check_presence_of_files {
  my @keys = (@ids ? @ids : keys %data );
  for my $id (@keys) {
    if (! -r "$redtxtdir/$id.txt") {
      printf STDERR "Warning: no reduced text file for $id.\n";
    }
  }
}
