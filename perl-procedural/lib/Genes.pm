# install perlmagick imagemagick-6-doc
# --------------------------------------------------
# Package stuff
package Genes;
$VERSION = v0.0.1;

use v5.28.1;
use warnings;
use strict;
use diagnostics;

use Exporter qw(import);
our @EXPORT_OK = qw/
  &best_distance
  &create_images
  &gene_start_length
  &generate_genes
  &get_best_gene_indices
  &image_dimensions
  &load_target_image
  &mate_genes
  &mate_percent
  &mate_population
  &max_population
  &max_radius
  &min_radius
  &mutate_percent
  &mutate_population
  &recursive_mutation_percent
  &save_gene
  &save_image
  &save_images
  &survival_percent
  /;


use Image::Magick;
use Data::Dumper;

my $START_POPULATION = 50;
my $GENE_START_LENGTH = 50;
my $SURVIVAL_PERCENT = 0.2;
my $MATE_PERCENT = 0.4;
my $MUTATE_PERCENT = 0.4;
my $RECURSIVE_MUTATION_PERCENT = 0.1;
my ($WIDTH, $HEIGHT) = (600, 600);
my $WIDTHXHEIGHT = $WIDTH . 'x' . $HEIGHT;
my $MAX_RADIUS = 100;
my $MIN_RADIUS = 4;

my $BEST_DISTANCE = 1;

# --------------------------------------------------
# Subs

sub best_distance()              { $BEST_DISTANCE              = shift || return $BEST_DISTANCE              }
sub max_population()             { $START_POPULATION           = shift || return $START_POPULATION           }
sub gene_start_length()          { $GENE_START_LENGTH          = shift || return $GENE_START_LENGTH          }
sub survival_percent()           { $SURVIVAL_PERCENT           = shift || return $SURVIVAL_PERCENT           }
sub mutate_percent()             { $MUTATE_PERCENT             = shift || return $MUTATE_PERCENT             }
sub recursive_mutation_percent() { $RECURSIVE_MUTATION_PERCENT = shift || return $RECURSIVE_MUTATION_PERCENT }
sub mate_percent()               { $MATE_PERCENT               = shift || return $MATE_PERCENT               }
sub max_radius()                 { $MAX_RADIUS                 = shift || return $MAX_RADIUS                 }
sub min_radius()                 { $MIN_RADIUS                 = shift || return $MIN_RADIUS                 }
sub image_dimensions() {
  my $w = shift;
  my $h = shift;
  return $WIDTHXHEIGHT unless ($w);
  ($WIDTH, $HEIGHT) = ($w, $h);
  $WIDTHXHEIGHT = "${WIDTH}x${HEIGHT}";
}

sub mutate_population() {
  my $population = shift;
  my $number_of_mutants = shift || int($START_POPULATION * $MUTATE_PERCENT);
  my @mutants;

  for (my $i = 0; $i < $number_of_mutants; $i++) {
    my $gene = @$population[int(rand(scalar @$population))];
    push @mutants, &mutate_gene(&dedup_gene($gene));
  }

  return \@mutants;
}


sub mutate_gene() {
  my $gene = shift;
  my $count = shift || 10;

  return $gene unless $count;

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

  # 1/10 chance of another mutation (unless change in strategy)
  my $newgene2 = \@newgene;
  $newgene2 = &mutate_gene(\@newgene, --$count)
    unless (int(rand(1 / $RECURSIVE_MUTATION_PERCENT)));

  return $newgene2;
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

sub deep_copy_gene() {
  my $g = shift;
  my @new_gene;


  # for now, just a deep copy.
  for (my $i = 0; $i < @$g; $i++) {
    my $a = $g->[$i];
    my @new_allele;
    for (my $j = 0; $j < @$a; $j++) {
      push @new_allele, $a->[$j];
    }
    push @new_gene, \@new_allele;
  }

  return \@new_gene;
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
  &best_distance($seed_distance);
  my $size = scalar @$population;

  print "$size genes loaded. The best gene has distance '$seed_distance' to image.\n";
  print "Creating " . ($START_POPULATION - $size) . " mutations of the seed.\n";

  my $old_rec_m = &recursive_mutation_percent();
  &recursive_mutation_percent(0.7);
  my $mutants = &mutate_population($population, $START_POPULATION - $size);
  &recursive_mutation_percent($old_rec_m);

  push @$population, @$mutants;
  return $population;
}

sub generate_genes_from_scratch() {
  my $population;
  for (my $i = 0; $i < $START_POPULATION; $i++) {
    push @$population, &generate_gene();
  }
  return $population;
}

sub generate_gene() {
  my @gene;
  for (my $i = 0; $i < $GENE_START_LENGTH; $i++) {
    push @gene, &generate_allele;
  }
  return \@gene;
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
    $drawing->Set(magick=>'PNG32');
    $drawing->Read('canvas:white');

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
  }

  my @distances_sorted = sort keys %{$distance_map};
  my $cut_off_index = int ($START_POPULATION * $SURVIVAL_PERCENT) - 1;
  my @best_matches = @distances_sorted[0.. $cut_off_index];
  &best_distance($best_matches[0]);

  my @indices;
  foreach my $distance (@best_matches) {
    push @indices, $distance_map->{$distance};
  }

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
