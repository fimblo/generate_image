#!/usr/bin/perl
use Image::Magick;
use Data::Dumper;
BEGIN { push @INC, 'lib/'}

use Genes qw/
  &set_bgimage
  &set_gene_start_length
  &set_max_population
  &set_max_radius
  &set_min_radius
  &set_survival_percent
  &set_mate_percent
  &set_mutate_percent
  &set_recursive_mutation_percent
  &generate_genes
  &create_images
  &get_comparisons_to_target
  &get_best_gene_indices
  &set_best_distance
  &mutate_population
  &mate_population
  &save_image
  &save_gene
  &diversify_population
  &scrub_gene
  &create_image
  /;



my $seed_filename = shift || die 'need gene seed filename.';
my $target_filename = shift || die 'need target filename';
my $target_image = Image::Magick->new;
$target_image->ReadImage($target_filename);



# load an old gene file

print "Loading file '$seed_filename'.\n";
open (my $FH, '<', $seed_filename) or die "cant open $seed_filename: $!";
my $rawdata = join '', <$FH>;
close $FH;

my $VAR1; eval $rawdata; die $! if $@;

my $population    = $VAR1->{'gene'};

# take first gene
my $orig_g = $population->[0];
print "Number of alleles in gene: " . scalar @$orig_g . "\n";

# scrub it
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

print << "EOM";
Original gene length: $orig_len\tdistance: $orig_diff
Scrubbed gene length: $scrub_len\tdistance: $scrub_diff
EOM
# save both as images.
$orig_drawing->Write('orig.png');
$scrub_drawing->Write('scrub.png');
