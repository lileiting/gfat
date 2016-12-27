#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use List::Util qw/min/;
our $in_desc = '<infile>';
use constant { 
    # Description of the script
    DESC_SCRIPT => 'Tools for proccessing results from MapQTL',

    # Description of each ACTION
    DESC_LOD_THRESHOLD => 'Extract LOD threhold from PT results'
};


sub main{
    my %actions = (
        lod_threshold => DESC_LOD_THRESHOLD,
        -desc => DESC_SCRIPT
    );
    &{\&{run_action(%actions)}};
}

main unless caller;

###########################################################

sub lod_threshold{
    my $args = new_action(
        -desc => DESC_LOD_THRESHOLD
    );

    warn "... Loading data ...\n";
    my $line_num = 0;
    my %data;
    for my $fh (@{$args->{in_fhs}}){
        my $title = <$fh>;
        chomp $title;
        my @title = split /\t/, $title;
        my %title = map{$title[$_] => $_}(0..$#title);
        die unless exists $title{q/Rel.cum.count/};
        die join(",", @title) unless exists $title{q/Trait/};
        die unless exists $title{q/Year/};
        die "$title" unless exists $title{q/Group/};
        die unless exists $title{q/Interval/};
        $line_num++;
        while(<$fh>){
            $line_num++;
            chomp;
            my @f = split /\t/;
            push @{ $data{$f[$title{Trait}]}->{$f[$title{Year}]
                }->{$f[$title{Group}]} }, 
                [$f[$title{Interval}], $f[$title{q/Rel.cum.count/}]];
        }
    }
    warn "... Finished! ($line_num lines) ...\n";

    for my $trait (sort {$a cmp $b} keys %data){
        for my $year (sort {$a <=> $b} keys %{$data{$trait}}){
            for my $group (sort {$a cmp $b} keys %{$data{$trait}->{$year}}){
                my @array = grep {$_->[1] >= 0.95} 
                    @{$data{$trait}->{$year}->{$group}};
                my $lod_threshold = min(map{$_->[0]}@array);

                print join("\t", $trait, $year, $group, $lod_threshold), "\n";
            }
        }
    }
}

__END__


