#!/usr/bin/perl
#
# (C) 2016-2018 Norbert Preining
# Licensed under GPL version 3 or higher
#
# Usage: the script reads from stdin and writes to stdout
#   cat text/NNNNN.txt | perl text-simplifier.pl > text-reduced/NNNNN.txt
#

$^W = 1;
use strict;

# start
# ***START OF THE PROJECT GUTENBERG EBOOK .....
#
# maybe afterwards
# E-text prepared by ... (one paragraph)
#

my $out = '';

my $accumulate = 0;
while (<>) {
  if (/^\*\*\*\s?START OF/) {
    $accumulate = 1;
    next;
  }
  if (/^\*\*\*\s?END OF (THIS|THE)/) {
    $accumulate = 0;
    next;
  }
  if ($accumulate) {
    if ($out eq '') {
      # we are past the header
      # read empty lines and lines 'Produced by ...'
      next if (/^\s*$/m);
      next if (/^Produced by/);
    }
    # skip a End of the Project Gutenberg
    next if (/^End of the Project Gutenberg/);
    # skip illustrations
    next if (/^\{[^}]*\.jpg\}/);
    next if (/^\[Illustration/);
    $out .= $_;
  }
}

# postprocess $out

# collapse multiple blank lines to one
$out =~ s/(\R)(?:\h*\R)+/$1$1/g;

print $out;

