# install perlmagick imagemagick-6-doc
# --------------------------------------------------
# Package stuff
package Genes;
$VERSION = v0.0.1;

use v5.28.1;
use warnings;
use strict;

use Exporter qw(import);
our @EXPORT_OK = qw/
  &set_best_distance
  &set_bgimage
  &set_debug
  &set_gene_start_length
  &set_image_dimensions
  &set_mate_percent
  &set_max_population
  &set_max_radius
  &set_min_radius
  &set_mutate_percent
  &set_survival_percent

  &generate_genes
  &create_images
  &get_comparisons_to_target
  &get_best_gene_indices

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

my $START_POPULATION = 50;
my $GENE_START_LENGTH = 50;
my $SURVIVAL_PERCENT = 0.2;
my $MATE_PERCENT = 0.4;
my $MUTATE_PERCENT = 0.4;
my ($WIDTH, $HEIGHT) = (600, 600);
my $WIDTHXHEIGHT = $WIDTH . 'x' . $HEIGHT;
my $MAX_RADIUS = 100;
my $MIN_RADIUS = 4;
my $BGIMAGE = 'canvas:white';

my $BEST_DISTANCE = undef;

# --------------------------------------------------
# Subs

sub set_bgimage()           { $BGIMAGE           = shift || return $BGIMAGE           }
sub set_best_distance()     { $BEST_DISTANCE     = shift || return $BEST_DISTANCE     }
sub set_debug()             { $DEBUG             = shift || return $DEBUG             }
sub set_max_population()    { $START_POPULATION  = shift || return $START_POPULATION  }
sub set_gene_start_length() { $GENE_START_LENGTH = shift || return $GENE_START_LENGTH }
sub set_survival_percent()  { $SURVIVAL_PERCENT  = shift || return $SURVIVAL_PERCENT  }
sub set_mutate_percent()    { $MUTATE_PERCENT    = shift || return $MUTATE_PERCENT    }
sub set_mate_percent()      { $MATE_PERCENT      = shift || return $MATE_PERCENT      }
sub set_max_radius()        { $MAX_RADIUS        = shift || return $MAX_RADIUS        }
sub set_min_radius()        { $MIN_RADIUS        = shift || return $MIN_RADIUS        }
sub set_image_dimensions() {
  my ($w, $h) = @_[0,1] || return [$WIDTH, $HEIGHT];
  ($WIDTH, $HEIGHT) = ($w, $h);
  $WIDTHXHEIGHT = "${WIDTH}x${HEIGHT}";
}

sub mutate_population() {
  my $population = shift;
  my $number_of_mutants = shift || int($START_POPULATION * $MUTATE_PERCENT);
  my @mutants;

  for (my $i = 0; $i < $number_of_mutants; $i++) {
    my $gene = @$population[int(rand(scalar @$population))];
    push @mutants, &mutate_gene($gene);
  }

  return \@mutants;
}


sub mutate_gene() {
  my $gene = shift;
  my $ran = int(rand(scalar @$gene)); # index of a random allele
  my $allele = &generate_allele;

  # add, modify, or remove an allele
  my @newgene = map { $_ } @$gene;
  my $selection = int(rand(3));
  if ($selection == 0) {        # add a new allele
    push @newgene, $allele;
  }
  elsif ($selection == 1) {     # remove a allele
    splice(@newgene, $ran, 1);
  }
  else {                        # modify an existing allele
    splice(@newgene, $ran, 1, $allele);
  }

  return &dedup_gene(\@newgene);
}


sub mate_population() {
  my $population = shift;
  my $number_of_children = int($START_POPULATION * $MATE_PERCENT);
  my @children;

  for (my $i = 0; $i < $number_of_children; $i++) {
    my $gene1 = @$population[int(rand(scalar @$population))];
    my $gene2 = @$population[int(rand(scalar @$population))];
    push @children, &mate_genes($gene1, $gene2);
  }

  return \@children;
}

sub mate_genes() {
  my @gene = @_[0,1];
  my @ran = map { int(rand(scalar @$_)) } @gene;

  my @first = @{$gene[0]}[0..$ran[0]];
  my @last  = @{$gene[1]}[-$ran[1]..-1];

  my @child = (@first, @last);

  return &dedup_gene(\@child);
}


sub dedup_gene() {
  my $gene = shift;
  my $hash;
  my @dedup;

  for my $g (@$gene) {
    my $str = join (',', @$g); # cuz its full of alleles
    unless (exists $hash->{$str}) {
      $hash->{$str} = 1;
      push @dedup, $g;
    }
  }
  return \@dedup;
}

sub drint() {
  my $msg = shift;
  print "DEBUG: $msg\n" if ($DEBUG eq 'TRUE');
}


sub load_target_image() {
  my $target_image_filename = shift;
  my $target_image = Image::Magick->new;

  $target_image->ReadImage($target_image_filename);
  return $target_image;
}



sub generate_allele() {
  my $x = int(rand($WIDTH));
  my $y = int(rand($HEIGHT));
  my $r = $MIN_RADIUS + int(rand($MAX_RADIUS - $MIN_RADIUS));

  return [
    $x,
    $y,
    $r,
    int(rand(255)), # Red
    int(rand(255)), # Green
    int(rand(255)), # Blue
    ];
}


sub generate_genes () {
  my $seed_file = shift;

  if ($seed_file) {
    return &generate_genes_from_seed($seed_file);
  }
  return &generate_genes_from_scratch();
}

sub generate_genes_from_seed() {
  my $seed_filename = shift;

  print "Loading file '$seed_filename'.\n";
  open (my $FH, '<', $seed_filename) or die "cant open $seed_filename: $!";
  my $rawdata = join '', <$FH>;
  close $FH;

  my $VAR1; # Data::Dumper saves the serialized data into this ref, so
            # we need to declare it
  eval $rawdata;
  die $! if $@;

  my $population    = $VAR1->{'gene'};
  my $seed_distance = $VAR1->{'distance'};
  my $size = scalar @$population;

  print "$size genes loaded. The best gene has distance '$seed_distance' to image.\n";
  print "Creating " . ($START_POPULATION - $size) . " mutations of the seed.\n";

  my $mutants = &mutate_population($population, $START_POPULATION - $size);

  push @$population, @$mutants;
  return $population;
}

sub generate_genes_from_scratch() {
  my $population;

  for (my $i = 0; $i < $START_POPULATION; $i++) {
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
  $Data::Dumper::Purity = 1;
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
    $drawing->Read($BGIMAGE);
    $drawing->Set(magick=>'PNG32');

    foreach my $allele (@$gene) {
      my ($x, $y, $rad, $r, $g, $b) = @$allele;
      my ($xr, $yr) = ($x, $y + $rad);
      $drawing->Draw(fill=>"rgb($r,$g,$b)", primitive=>'circle', points=>"$x,$y $xr,$yr");
    }
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
  my $target_filename = shift;
  my $distance_map;

  my $target = &load_target_image($target_filename);

  foreach my $index (keys %$images) {
    my $result = $target->Compare(image=>$images->{$index}, metric=>'mae');
    my $diff = $result->Get('error');
    $distance_map->{$diff} = $index;

    #print "$index -> $diff\n";
  }

  my @distances_sorted = sort keys %{$distance_map};
  my $cut_off_index = int ($START_POPULATION * $SURVIVAL_PERCENT) - 1;
  my @best_matches = @distances_sorted[0.. $cut_off_index];
  &set_best_distance($best_matches[0]);

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
