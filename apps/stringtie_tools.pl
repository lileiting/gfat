#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main {
    my %actions = (
        merge => 'Merge multiple GTF files and only keep the FPKM data'
    );
    &{ \&{ run_action (%actions) } };
}

main unless caller;

############################################################

sub merge {
    my $args = new_action(
        -desc => 'Merge multiple GTF files and only keep the FPKM data'
    );

    my %data;
    my %transcript_id;
    for my $i ( 0 .. $#{$args->{infiles}} ) {
        my $file = $args->{infiles}->[$i];
        my $fh = $args->{in_fhs}->[$i];
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            chomp;
            my @f = split /\t/;
            next unless $f[2] eq 'transcript';
            $f[8] =~ s/; *$//;
            my %ann = map{ split / / } (split /; /, $f[8]);
            die unless exists $ann{transcript_id} and
                       exists $ann{FPKM};
            $data{$file}->{ $ann{transcript_id} } = $ann{FPKM};
            $transcript_id{ $ann{transcript_id} }++;
        }
    }

    my @transcript_id = sort {$a cmp $b} keys %transcript_id;
    print join(",", 'Sample', @transcript_id) . "\n";
    for my $file (sort {$a cmp $b} keys %data) {
        print join(",", $file, map{$data{$file}->{$_}}@transcript_id ) . "\n";
    }
}



__END__
