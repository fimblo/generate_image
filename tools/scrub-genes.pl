#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;
use File::Basename;
use Getopt::Long;
use Image::Magick;
BEGIN { push @INC, 'lib/'}

use Genes qw/
              &save_gene
              &scrub_gene
              &create_image
            /;



# --------------------------------------------------
# Help message
my $basename = basename($0);
my $helptext = << "EOM";
Given a gene file, remove alleles from each gene with minimal lossage.

   ${basename} -t <target-file> -g <gene-file> -o <output-file>

  -t --target-file  # image to approximate
  -g --gene-file    # file with genes
  -o --output-file  # where to put the scrubbed genes

EOM

my $target_filename;
my $gene_filename;
my $output_filename;
my $help;

GetOptions(
           "target-file=s" => \$target_filename,
           "gene-file=s"   => \$gene_filename,
           "output-file=s" => \$output_filename,
           "help"          => \$help,
          ) or die ("bad commandline args\n");

if ( ! $target_filename  or
     ! $gene_filename    or
     ! $output_filename  or
     $help
   ) {
  print $helptext;
  exit 0;
}


# load target image file
print "Loading target image '$target_filename'\n";
my $target_image = Image::Magick->new;
$target_image->ReadImage($target_filename);



# load gene file for scrubbing
print "Loading genes from '$gene_filename'.\n";
open (my $FH, '<', $gene_filename) or die "cant open $gene_filename: $!";
my $rawdata = join '', <$FH>;
close $FH;
my $VAR1; eval $rawdata; die $! if $@;


# Prep for scrubbing
my $population = $VAR1->{'gene'};
my $pop_len = scalar @$population;
my $best_old_distance = 1;      # for comparison between loops
my $best_new_distance = 1;      # for comparison between loops
my @scrubbed_genes;             # store scrubbed genes here
my $ui;                         # store UI-related data here
my $cnt = 0;                    # counter for loop
$| = 1;                         # Turn off buffered output

for my $orig_g (@{$population}[0..2]) {
  print "Gene $cnt/$pop_len:";
  my $scrub_g = &scrub_gene($orig_g, $target_filename);

  # for both: check distance to target file
  my $r;
  my $orig_drawing = &create_image($orig_g);
  $r = $target_image->Compare(image=>$orig_drawing, metric=>'mae');
  my $orig_diff = $r->Get('error');
  my $orig_len = @$orig_g;

  my $scrub_drawing = &create_image($scrub_g);
  $r = $target_image->Compare(image=>$scrub_drawing, metric=>'mae');
  my $scrub_diff = $r->Get('error');
  my $scrub_len = @$scrub_g;

  $best_new_distance = $scrub_diff if ($scrub_diff < $best_new_distance);

  print "\n";
  $ui->{$cnt}->{old}->{len} = $orig_len;
  $ui->{$cnt}->{old}->{distance} = $orig_diff;
  $ui->{$cnt}->{new}->{len} = $scrub_len;
  $ui->{$cnt}->{new}->{distance} = $scrub_diff;

  push @scrubbed_genes, $scrub_g;
  $cnt++;
}



# Save the scrubbed genes to disk
&save_gene(
           { distance => $best_new_distance,
             gene => \@scrubbed_genes },
           $output_filename
          );



# Finally, report to user
my ($gnr, $lo, $ln, $lp, $do, $dn, $dp);
for my $k (sort keys %$ui) {
  $gnr = $k;
  $lo = $ui->{$k}->{old}->{len};
  $ln = $ui->{$k}->{new}->{len};
  $lp = sprintf("%.2f%%", (($ln / $lo) * 100));
  $do = $ui->{$k}->{old}->{distance};
  $dn = $ui->{$k}->{new}->{distance};
  $dp = sprintf("%.4f%%", (($dn / $do) * 100));
  write;
}

exit 0;




# Report format
format STDOUT_TOP =
        Length                Distance
Gene    Old    New    %       Old            New            ‰
-----------------------------------------------------------------------
.

format STDOUT =
@>>>>   @>>>>  @>>>>  @>>>>>  @<<<<<<<<<<<<< @<<<<<<<<<<<<< @<<<<<<<<<<
$gnr,   $lo,   $ln,   $lp,    $do,           $dn,           $dp
.

