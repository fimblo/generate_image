# install perlmagick imagemagick-6-doc
# --------------------------------------------------
# Package stuff
package Genes;
$VERSION = v.0.0.1;

use v5.28.1;
use warnings;
use strict;

use Exporter qw(import);
our @EXPORT_OK = qw/
  &set_debug
  &set_max_population
  &set_gene_start_length
  &set_survival_percent
  &set_mutate_percent
  &set_mate_percent
  &set_max_radius
  &set_image_dimensions

  &generate_genes
  &create_images
  &get_comparisons_to_source
  &get_best_gene_indices
  &get_best_distance

  &mate_population
  &mate_genes

  &mutate_population
  &mutate_genes

  &save_gene
  &save_image
  &save_images
  /;


use Image::Magick;
use Data::Dumper;

my $DEBUG = 'TRUE';

my $MAX_POPULATION = 50;
my $GENE_START_LENGTH = 30;
my $SURVIVAL_PERCENT = 0.2;
my $MATE_PERCENT = 0.6;
my $MUTATE_PERCENT = 0.2;
my ($WIDTH, $HEIGHT) = (600, 600);
my $WIDTHXHEIGHT = $WIDTH . 'x' . $HEIGHT;
my $MAX_RADIUS = 255;
my $BEST_DISTANCE = -1;

# --------------------------------------------------
# subs

sub get_best_distance()     { return $BEST_DISTANCE;                                  }
sub set_debug()             { $DEBUG             = shift || return $DEBUG             }
sub set_max_population()    { $MAX_POPULATION    = shift || return $MAX_POPULATION    }
sub set_gene_start_length() { $GENE_START_LENGTH = shift || return $GENE_START_LENGTH }
sub set_survival_percent()  { $SURVIVAL_PERCENT  = shift || return $SURVIVAL_PERCENT  }
sub set_mutate_percent()    { $MUTATE_PERCENT    = shift || return $MUTATE_PERCENT    }
sub set_mate_percent()      { $MATE_PERCENT      = shift || return $MATE_PERCENT      }
sub set_max_radius()        { $MAX_RADIUS        = shift || return $MAX_RADIUS        }
sub set_image_dimensions() {
  my ($w, $h) = @_[0,1] || return [$WIDTH, $HEIGHT];
  ($WIDTH, $HEIGHT) = ($w, $h);
  $WIDTHXHEIGHT = "${WIDTH}x${HEIGHT}";
}

sub mutate_population() {
  my $population = shift;
  my $number_of_mutants = int($MAX_POPULATION * $MUTATE_PERCENT);
  my @mutants;

  for (my $i = 0; $i < $number_of_mutants; $i++) {
    my $gene = @$population[int(rand(scalar @$population))];
    push @mutants, mutate_gene($gene);
  }

  return \@mutants;
}


sub mutate_gene() {
  my $gene = shift;
  my $ran = int(rand(scalar @$gene)); # index of a random allele
  my $allele = &generate_allele;

  splice(@$gene, $ran, 1, $allele);
  return $gene;
}


sub mate_population() {
  my $population = shift;
  my $number_of_children = int($MAX_POPULATION * $MATE_PERCENT);
  my @children;

  for (my $i = 0; $i < $number_of_children; $i++) {
    my $gene1 = @$population[int(rand(scalar @$population))];
    my $gene2 = @$population[int(rand(scalar @$population))];
    push @children, mate_genes($gene1, $gene2);
  }

  return \@children;
}

sub mate_genes() {
  my @gene = @_[0,1];
  my @ran = map { int(rand(scalar @$_)) } @gene;

  my @first = @{$gene[0]}[0..$ran[0]];
  my @last  = @{$gene[1]}[-$ran[1]..-1];

  my @child = (@first, @last);
  #print "$_ " for @child; print "\n";
  return \@child;
}


sub drint() {
  my $msg = shift;
  print "DEBUG: $msg\n" if ($DEBUG eq 'TRUE');
}


sub load_source_image() {
  my $source_image_filename = shift;
  my $source_image = Image::Magick->new;

  $source_image->ReadImage($source_image_filename);
  return $source_image;
}



sub generate_allele() {
  my $x = int(rand($WIDTH));
  my $y = int(rand($HEIGHT));
  my $r = int(rand($MAX_RADIUS));

  return [
    $x,
    $y,
    $r,
    int(rand(255)), # Red
    int(rand(255)), # Green
    int(rand(255)), # Blue
    ];
}

sub generate_genes() {
  my $population;

  for (my $i = 0; $i < $MAX_POPULATION; $i++) {
    my $gene_len = $GENE_START_LENGTH;
    my @gene;
    for (my $j = 0; $j < $gene_len; $j++) {
      push @gene, &generate_allele;
    }
    #    $population->{index} = $i;
    push @$population, \@gene;
  }
  return $population;
}


sub save_gene() {
  my $gene = shift;
  my $name = shift || 'gene.txt';

  use Data::Dumper;
  $Data::Dumper::Indent = 0;
  open(my $OUT, '>', $name) or die "can't save file. $!\n";
  print $OUT Dumper($gene);
  close $OUT;
}


sub save_image () {
  my $image = shift;
  my $filename = shift || "image.png";

  my $err = $image->Write($filename);
  die "$err" if "$err";
}


sub save_images () {
  my $images = shift;

  my $len = scalar @{$images};
  for (my $i = 0; $i < $len; $i++) {
    &save_image($images->[$i], "image-$i.png");
  }
}

sub create_image() {
    my $gene = shift;
    my $drawing = Image::Magick->new;
    $drawing->Set(size=>"$WIDTHXHEIGHT");
    $drawing->Read('canvas:white');
    $drawing->Set(magick=>'PNG32');

    foreach my $allele (@$gene) {
      my ($x, $y, $rad, $r, $g, $b) = @$allele;
      my ($xr, $yr) = ($x, $y + $rad);
      $drawing->Draw(fill=>"rgb($r,$g,$b)", primitive=>'circle', points=>"$x,$y $xr,$yr");
    }
    #&save_image($drawing);
   return $drawing;
}

sub create_images() {
  my $population = shift;
  my $images;
  $| = 1;
  print "Creating images:";
  for (my $gn = 0; $gn < scalar @$population; $gn++) {
    print ":";
    $images->{$gn} = &create_image($population->[$gn]);
  }
  print "\n";
  $| = 0;
  return $images;
}

sub get_best_gene_indices () {
  my $images = shift;
  my $source_filename = shift;
  my $distance_map;

  my $source = &load_source_image($source_filename);

  foreach my $index (keys %$images) {
    my $result = $source->Compare(image=>$images->{$index}, metric=>'mae');
    my $diff = $result->Get('error');
    $distance_map->{$diff} = $index;

    #print "$index -> $diff\n";
  }

  my @distances_sorted = sort keys %{$distance_map};
  my $cut_off_index = int ($MAX_POPULATION * $SURVIVAL_PERCENT) - 1;
  my @best_matches = @distances_sorted[0.. $cut_off_index];
  $BEST_DISTANCE = $best_matches[0];

  my @indices;
  foreach my $distance (@best_matches) {
    push @indices, $distance_map->{$distance};
  }

  # &drint("cut-off: $cut_off_index");
  # &drint("length of array " . scalar @best_matches);

  return \@indices;
}




# Quick look into the population (works with small populations)
sub show_population() {
  my $population = shift;
  foreach my $gene (@$population) {
    print "(";
    foreach my $allele (@$gene) {
      print join (',', @$allele) . "\n";
    }
    print ")\n";
  }
}






1;
