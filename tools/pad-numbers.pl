#!/usr/bin/perl

my $pad_size = shift || 5;

while (<>) {
  my $line = $_;
  chomp $line;
  my $orig = $line;

  if ($line =~ /^.*?(\d+).*?$/) {
    my $digits = $1;
    my $len = length $digits;
    my $pad;
    if ($pad_size > $len) {
      $pad = $pad_size - $len;
      $digits = '0'x$pad . $digits;
    }
    $line =~ s/(\d+)/$digits/;

    print "mv $orig $line\n";
  }
}
