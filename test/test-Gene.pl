#!/usr/bin/perl

use 5.10.0;
use warnings;
use strict;
use Data::Dumper;

BEGIN { push @INC, qw|lib/ ../lib/ |}

use Gene;

say "Constructor test";
my $gene = Gene->new();
my $ans = {
           size_of => 100,
          };
for (keys %$ans) {
  my $k = $_;
  if ($gene->{$k} == $ans->{$k}) {
    say "OK: $k";
  } else {
    say "NOT OK: $k";
  }
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


# Set artificially small gene pool with small values
my @num_array = (0 .. 15);
my @ident_array = split //, '0' x 16 ;
Gene->max_val(scalar @num_array);
Gene->init_alleles(scalar @num_array);
my $mutant;


for my $i (1 .. 6) {
  $gene = Gene->new({alleles => \@num_array, size_of => scalar @num_array});
  say ' ' . $title->{$i};
  say ' ' . $msg->{$i};

  $mutant = $gene->mutate($i);
  say '   ' . $gene->to_string();
  say '   ' . $mutant->to_string();
  say '';
}


say "Testing Mating functionality";

my @alpha_array = ('a' .. 'p');
my $num_gene = Gene->new({alleles => [ @num_array ]});
my $alpha_gene = Gene->new({alleles => [ @alpha_array ]});
my $child = $num_gene->mate($alpha_gene);
say '  ' . $num_gene->to_string();
say '  ' . $alpha_gene->to_string();
say '  ' . $child->to_string();
