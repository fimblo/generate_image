#!/usr/bin/perl
# --------------------------------------------------
# This quick and dirty script takes gene files saved by Gene.pm and
# recreates images of the best image from each gene file.
#
# Later, take the output image files and create a movie, like so:
#
# mencoder "mf://*.png" -o movie.avi -ovc lavc -lavcopts vcodec=mjpeg

#
# Mattias Jansson <fimblo@yanson.org>
# --------------------------------------------------

use v5.28.1;
use warnings;
use strict;

BEGIN { push @INC, 'lib/'}
use Genes qw/ &create_image &save_image /;


$|=1; # turn autoflush on.
my $gd = shift || die "Please supply a directory with gene files.";

print "Loading genes and creating images.\n";
opendir(my $dh, $gd) || die "Can't opendir '$gd': $!\n";

my $i=0;
my @listing = sort(readdir $dh);
while (my $gf = shift @listing ) {
  next unless ($gf =~ /gene/);

  open (my $FH, '<', "$gd/$gf") or die "cant open $gf: $!";
  my $rawdata = join '', <$FH>;
  close $FH;

  my $VAR1; eval $rawdata; die $! if $@;

  my $best = $VAR1->{'gene'};
  my $drawing = &create_image($best->[0]);

  my $pad_size = 9;
  my $padding = '0'x ($pad_size - length($i));
  mkdir "output" unless ( -d "output" );
  mkdir "output/recreate-$$" unless ( -d "output/recreate-$$" );
  &save_image($drawing, "output/recreate-$$/image_${padding}${i}.png");

  print '.';
  $i++;
}
closedir $dh;


print "\nLoaded $i genes.\n";

exit;
