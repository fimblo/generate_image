#!/usr/bin/perl
use v5.18;
use warnings;
use strict;

BEGIN { push @INC, qw|lib/ ../lib/ |}

use Individual;

say "Constructor test";
my $individual = Individual->new();
my $ans = {
           size_of => 100,
          };
for (keys %$ans) {
  my $k = $_;
  if ($individual->{$k} == $ans->{$k}) {
    say "  OK: $k";
  } else {
    say "  NOT OK: $k";
  }
}

say "Save individual to disk.";
my $filename ="/tmp/test-Individual-saveload-$$.txt";
$individual = Individual->new({ alleles => [ 1, 2, 3, 4, 5]});
$individual->save_to_disk($filename);
if (-e $filename) {
  say "  OK: Saved to disk";
} else {
  say "  Not OK: Did not save to disk";
}

say "Retrieve individual from disk - instance method";
my $retrieved = $individual->load_from_disk($filename);
my $old_alleles = join(',', @{$individual->alleles()});
my $new_alleles = join(',', @{$retrieved->alleles()});
if ($old_alleles eq $new_alleles) {
  say "  OK: restored nicely."
} else {
  say "  NOT OK: could not restore";
}

say "Retrieve individual from disk - class method";
$retrieved = Individual->new({filename => $filename});
$old_alleles = join(',', @{$individual->alleles()});
$new_alleles = join(',', @{$retrieved->alleles()});
if ($old_alleles eq $new_alleles) {
  say "  OK: restored nicely."
} else {
  say "  NOT OK: could not restore";
}






say "++++++++++++++++++++++++++++++++++++++++++++++++++";
say "Ocular testing required from here.";
say "++++++++++++++++++++++++++++++++++++++++++++++++++";

say "Testing Mutation functions";
my $title = {
             1 => "Insert mutation test",
             2 => "Inversion mutation test",
             3 => "Scramble mutation test",
             4 => "Swap mutation test",
             5 => "Reversing mutation test",
             6 => "Creeping mutation test",
            };
my $msg = {
           1 => "Select two alleles at random (a1, a2). Insert a2 after a1, shifting the rest upwards",
           2 => "Select two alleles at random, then invert the alleles values between them",
           3 => "Select subset of alleles, and move them to each others' locations without changing them",
           4 => "Select two alleles and swap their locations",
           5 => "Select two alleles at random, then reverse the location order of the alleles between them",
           6 => "Select an allele and replace it with a random value",
          };


# Set artificially small individual pool with small values
my @num_array = (0 .. 15);
my @ident_array = split //, '0' x 16 ;
Individual->max_val(scalar @num_array);
Individual->init_alleles(scalar @num_array);
my $mutant;


for my $i (1 .. 6) {
  $individual = Individual->new({alleles => \@num_array, size_of => scalar @num_array});
  say ' ' . $title->{$i};
  say ' ' . $msg->{$i};

  $mutant = $individual->mutate($i);
  say '   ' . $individual->to_string();
  say '   ' . $mutant->to_string();
  say '';
}


say "Testing Mating functionality";

my @alpha_array = ('a' .. 'p');
my $num_individual = Individual->new({alleles => [ @num_array ]});
my $alpha_individual = Individual->new({alleles => [ @alpha_array ]});
my $child = $num_individual->mate($alpha_individual);
say '  ' . $num_individual->to_string();
say '  ' . $alpha_individual->to_string();
say '  ' . $child->to_string();

