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
  &set_recursive_mutation_percent
  &set_survival_percent

  &diversify_population

  &generate_genes
  &generate_gene
  &create_images
  &create_image
  &get_comparisons_to_target
  &get_best_gene_indices

  &mate_population
  &mate_genes

  &mutate_population
  &mutate_genes

  &save_gene
  &save_image
  &save_images

  &scrub_gene
  /;


use Image::Magick;
use Data::Dumper;

my $DEBUG = 'TRUE';

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
my $BGIMAGE = 'canvas:white';

my $BEST_DISTANCE = undef;

# --------------------------------------------------
# Subs

sub set_bgimage()                    { $BGIMAGE                    = shift || return $BGIMAGE                    }
sub set_best_distance()              { $BEST_DISTANCE              = shift || return $BEST_DISTANCE              }
sub set_debug()                      { $DEBUG                      = shift || return $DEBUG                      }
sub set_max_population()             { $START_POPULATION           = shift || return $START_POPULATION           }
sub set_gene_start_length()          { $GENE_START_LENGTH          = shift || return $GENE_START_LENGTH          }
sub set_survival_percent()           { $SURVIVAL_PERCENT           = shift || return $SURVIVAL_PERCENT           }
sub set_mutate_percent()             { $MUTATE_PERCENT             = shift || return $MUTATE_PERCENT             }
sub set_recursive_mutation_percent() { $RECURSIVE_MUTATION_PERCENT = shift || return $RECURSIVE_MUTATION_PERCENT }
sub set_mate_percent()               { $MATE_PERCENT               = shift || return $MATE_PERCENT               }
sub set_max_radius()                 { $MAX_RADIUS                 = shift || return $MAX_RADIUS                 }
sub set_min_radius()                 { $MIN_RADIUS                 = shift || return $MIN_RADIUS                 }
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



sub scrub_gene() {
  my $gene = shift;
  my $target_filename = shift;
  my $target = &load_target_image($target_filename);
  my @retarr;


  sub _helper_single {
    my $gene        = shift;
    my $transparent = shift;
    my $layer = $transparent->Clone();

    for my $allele (@$gene) {
      my ($x, $y, $rad, $r, $g, $b) = @$allele;
      my ($xr, $yr) = ($x, $y + $rad);
      $layer->Draw(fill=>"rgb($r,$g,$b)", primitive=>'circle', points=>"$x,$y $xr,$yr");
    }
    return $layer;
  }

  sub _helper_multi {
    my $gene        = shift;
    my $transparent = shift;
    my @retarr;

    for my $allele (@$gene) {
      my ($x, $y, $rad, $r, $g, $b) = @$allele;
      my ($xr, $yr) = ($x, $y + $rad);
      my $layer = $transparent->Clone();
      $layer->Draw(fill=>"rgb($r,$g,$b)", primitive=>'circle', points=>"$x,$y $xr,$yr");
      push @retarr, $layer;
    }
    return \@retarr;
  }


  use POSIX;

  # we'll put all images as layers into this in array context, like so:
  # push @$base, $some_image;
  my $base = Image::Magick->new(size=>$WIDTHXHEIGHT, magick=>'PNG32' );
  $base->ReadImage('canvas:white');

  # each image will be drawn onto this transparent layer.
  my $transparent = Image::Magick->new(size=>'800x600');
  $transparent->ReadImage('null:');

  my @indices_to_keep;
  my $gene_len = @$gene;
  my $chunk_size = 50;
  my $number_of_chunks = ceil($gene_len / $chunk_size);
  print "Number of alleles in gene: $gene_len\n";
  print "Splitting up into $number_of_chunks chunks\n";

  my $skip = 0;
  for (my $i = 0; $i < $number_of_chunks; $i++) {
    if ($number_of_chunks > 4 and $i == $number_of_chunks - 3) {
      print "Skipping last three rounds\n";
      $skip = 1;
    }

    print "Chunk $i\n";
    my @first_layer = ();
    my @middle_layers = ();
    my @last_layer = ();


    my $start_index = $chunk_size * $i;
    my $end_index = ($chunk_size * ( $i + 1)) - 1; # otherwise it will be 100, not 99.
    $end_index = $gene_len - 1 if ($end_index > $gene_len);

    my $first =  [ @{$gene}[ (0               ..  ${start_index}-1 )] ];
    my $middle = [ @{$gene}[ (${start_index}  ..  ${end_index}     )] ];
    my $last =   [ @{$gene}[ (${end_index}+1  ..  -1               )] ];

    if ($i == 0) {
      @first_layer = ();
    }
    else {
      @first_layer =  &_helper_single($first , $transparent);
    }

    # always do the middle rounds
    @middle_layers = @{ &_helper_multi( $middle, $transparent) };

    if ($i == $number_of_chunks - 1) {
      @last_layer = ();
    }
    else {
      @last_layer = &_helper_single($last, $transparent);
    }

    # Flatten all layers and get distance to target image.  Any later
    # removals of a layer which leads to no change in distance means
    # that layer had no real impact, only cost. These will be removed
    # from the gene.
    my $temp_base = $base->Clone();
    push @$temp_base, (@first_layer, @middle_layers, @last_layer);
    my $flat = $temp_base->Flatten(background=>'none');
    my $result = $target->Compare(image=>$flat, metric=>'mae');
    my $distance = $result->Get('error');

    #print "# of middle layers: " . scalar @middle_layers . "\n";
    for (my $j = 0; $j < @middle_layers; $j++) {
      my $allele_nr = ($chunk_size * $i) + $j;
      print "Allele $allele_nr/$gene_len:";

      if ($skip ) { # don't do last chunks
        print "\tkeep.\n";
        push @indices_to_keep, $allele_nr;
        next;
      }

      my $removed_layer = splice(@middle_layers, $j, 1);
      # do distance check

      $temp_base = $base->Clone();
      push @$temp_base, (@first_layer, @middle_layers, @last_layer);
      my $tmp = $temp_base->Flatten(background => 'none');
      my $res = $target->Compare(image => $tmp, metric => 'mae');
      my $local_distance = $res->Get('error');

      # return the allele
      splice(@middle_layers, $j, 0, $removed_layer);

      if ($local_distance > $distance ) { # removing the allele made things worse
        print "\tkeep.\n";
        push @indices_to_keep, $allele_nr;
      } else {     #removing the allele made things better or the same
        print "\tremove.\n";
      }
    }
  }

  @retarr = @{$gene}[@indices_to_keep];
  my $old_len = @$gene;
  my $new_len = @retarr;

  print "Scrubbed Gene. Old len: $old_len, New len: $new_len\n" if ($new_len < $old_len);
  return \@retarr;
}




sub diversify_population() {
  my $population = shift;
  my $target_filename = shift;
  my @new_population;

  print "Diversifying " . scalar @$population . " genes.\n";

  my $target = &load_target_image($target_filename);
  my $cnt = 0;
  my $ui_dist;
  $|=1;
  for my $g (@$population) {
    print "Gene #".$cnt;
    my $gene = &scrub_gene($g);
    my $drawing = &create_image($gene);

    my $result = $target->Compare(image=>$drawing, metric=>'mae');
    my $distance = $result->Get('error');
    print ": Improve from $distance to ";

    my $more_mutations_wanted = 20;
    while ($more_mutations_wanted) {
      my $allele = &generate_allele;
      my ($x, $y, $rad, $r, $g, $b) = @$allele;
      my ($xr, $yr) = ($x, $y + $rad);
      my $temp_drawing = $drawing->Clone();

      $temp_drawing->Draw(fill=>"rgb($r,$g,$b)", primitive=>'circle', points=>"$x,$y $xr,$yr");
      my $res = $temp_drawing->Compare(image=>$target, metric=>'mae');
      my $local_distance = $res->Get('error');

      if ($local_distance < $distance) {
        $ui_dist = $distance = $local_distance;
        $drawing = $temp_drawing;
        push @$gene, $allele;
        $more_mutations_wanted--;
      }
    }
    print "$ui_dist\n";
    $cnt++;
    push @new_population, $gene;
  }
  $|=0;
  return \@new_population;
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

  my $old_rec_m = &set_recursive_mutation_percent();
  &set_recursive_mutation_percent(0.7);
  my $mutants = &mutate_population($population, $START_POPULATION - $size);
  &set_recursive_mutation_percent($old_rec_m);

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
  }

  my @distances_sorted = sort keys %{$distance_map};
  my $cut_off_index = int ($START_POPULATION * $SURVIVAL_PERCENT) - 1;
  my @best_matches = @distances_sorted[0.. $cut_off_index];
  &set_best_distance($best_matches[0]);

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
