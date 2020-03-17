#!/usr/bin/perl

# Assumes input is in sorted order.

my $num      = shift || 0;
my $pad_size = shift || 6;

while (<>) {
  my $line = $_;
  chomp $line;
  my $orig = $line;

  if ($line =~ /^.*?(\d+).*?$/) {
    my $digits = $1;
    my $pad = $pad_size - length($num);
    my $replace = '0'x$pad . $num;
    $line =~ s/(\d+)/$replace/;
    print "mv $orig $line\n";
    $num++;
  }
}
