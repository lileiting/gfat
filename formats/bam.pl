#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
our $in_desc = '<in.bam> [in.bam ...]';

sub main{
    my %actions = (
        cram => 'Print shell commands to convert bam to cram'
    );

    &{ \&{ run_action(%actions) } };
}

sub cram {
    my $args = new_action(
        -desc => 'Print shell commands to convert bam to cram',
        -options => {
            "reference|T=s" => 'Path for reference'
        }
    );

    my $ref = $args->{options}->{reference};
    die "CAUTION: Reference is quired for bam2cram convertion" 
        unless $ref;

    map{ die "Input file must with suffix '.bam'" 
             unless /\.bam$/
    } @ARGV;


    for my $bam (@ARGV){
        my $cram = $bam;
        $cram =~ s/\.bam$/.cram/;
        print "samtools view -C -T $ref -o $cram $bam\n";
    }
}

main unless caller;

__END__

