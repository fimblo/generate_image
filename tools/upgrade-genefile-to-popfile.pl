#!/usr/bin/perl
use v5.28.1;
use warnings;
use strict;
use Getopt::Std;
use Data::Dumper;

# --------------------------------------------------
# CLI fu. Sanity checks.
my %opts;
getopts('g:i:o:t:h', \%opts);

my $errmsg =
  {
   i => "-i <file>\nSource gene file. Contains a hash with two k/v pairs. 'gene' and 'distance'.\nSaved using Data::Dumper.\n",
   o => "-o <file>\nTarget pop file. Place to save the converted population file.\n",
   t => "-t <file>\nThe filename of the image which the genes are aspiring to become.\n",
   g => "-g <int>\nNumber of generations the population has gone through.\n",
  };

for my $p (qw/i o t g/) {
  die $errmsg->{$p} unless exists($opts{$p});
}
die "File '". $opts{i}. "' not found." unless ( -e $opts{i} );
my $gene_filename = $opts{i};
my $population_filename = $opts{o};
my $target_image_filename = $opts{t};
my $generations = $opts{g};


# --------------------------------------------------
# Try to load old gene file.
print "Loading file '$gene_filename'.\n";
open (my $FH, '<', $gene_filename) or die "cant open $gene_filename: $!";
my $rawdata = join '', <$FH>;
close $FH;

my $VAR1; eval $rawdata;
die $! if $@;

die ("Syntax error in file '$gene_filename'. Please check.")
  unless (exists($VAR1->{'gene'}) and exists($VAR1->{'distance'}));

my $old_population    = $VAR1->{'gene'};
my $old_best_distance = $VAR1->{'distance'};


# --------------------------------------------------
# Convert from old datastructure to new

sub CIRCLE { 0 };

my @individuals;
my $gene_cnt = 0;
for my $gene (@$old_population) {
  my $new_allele_cnt = 0;
  my @new_gene;
  for my $allele (@$gene) {
    push @new_gene, ($new_allele_cnt++, @$allele);
  }
  my $old_allele_cnt = @$gene;

  my $individual;
  $individual->{gene} = \@new_gene;
  push @individuals, $individual;


  my $msg = "O: $old_allele_cnt N: $new_allele_cnt OK\n";
  $msg =~ s/OK/Mismatch/g  if ($old_allele_cnt != $new_allele_cnt);
  print $msg;

  $gene_cnt++;
}
print "Old pop size: " . @$old_population . "\n";
print "New pop size: " . @individuals . "\n";



# --------------------------------------------------
# Save new format
my $current_state;
$current_state->{generations} = $generations;
$current_state->{target} = $target_image_filename;
$current_state->{best_distance} = $old_best_distance;
$current_state->{individuals} = \@individuals;
$current_state->{fileversion} = '1';

$Data::Dumper::Indent = 0;
$Data::Dumper::Purity = 1;
open(my $OUT, '>', $population_filename) or die "can't save file. $!\n";
print $OUT Dumper($current_state);
close $OUT;

print "Saved new population file to '$population_filename'.\n";
