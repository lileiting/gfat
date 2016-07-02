#!/usr/bin/env perl

use warnings;
use strict;
use File::Find;
use Digest::MD5 qw( md5_hex );

my %md5;
find(\&wanted, '.');

sub wanted{
    return 0 if -d $_ or /^\./;

    open my $fh, '<', $_ or die "$!: $_";
    my $md5 = Digest::MD5->new->addfile($fh)->hexdigest;
    close $fh;
    push @{$md5{$md5}}, $File::Find::name;
    print "$md5\t$File::Find::name\n";
}

for my $md5 (keys %md5){
    my @files = @{$md5{$md5}};
    next unless @files > 1;
    print "\n$md5:\n";
    for my $file (@files){
        print "    $file\n";
    }
}
