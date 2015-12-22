#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw(sum max);
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    print <<"usage";

Usage
    $FindBin::Script ACTION [OPTIONS]

Description
    Manipulate genetic map data
    Default genetic map input data format is 4-column

    map_ID	marker_name	LG	genetic_pos

    Space was not allowed in map_ID and marker_name

Availabe actions
    blastn2allmaps   | Prepare input data for allmaps
    bowtie2allmaps   | Prepare input data for allmaps
    mergemap         | Prepare input data for mergemap
    mergemapLG       | one file per LG 
    commonstats      | Count common markers
    summarymap       | Summary of input data
    linear_map_chart | read linear_map_chart files
    binmarkers       | Find bin markers
    input4R          | Get input data for R codes
    drawfigureR      | print R codes for drawing genetic map figure
    consensus2allmaps| Convert consensus map data as ALLMAPS input format 

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    our $format = 'fasta';
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}}; 
    }
    else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main() unless caller;

############################################################
# Action defination                                        #
############################################################

#
# Map data
#

sub load_map_data2{
    my $args = shift;
    my %map_data;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            unless(/^(\S+)\t(\S+)\t(\S+)\t(-?\d+(\.\d+)?)$/){
                warn "[load_map_data2] WARNING: $_\n";
                next;
            }
            my ($map_id, $LG, $marker_name, $genetic_pos)
                = ($1, $2, $3, $4);
            #die "Duplicated marker: $marker_name!!!\n" 
            #    if $map_data{$map_id}->{$marker_name};
            #$map_data{$map_id}->{$marker_name} = [$LG, $genetic_pos];
            $map_data{$map_id}->{$LG}->{$marker_name} = $genetic_pos;
        }
    }
    die "[load_map_data] ERROR: No map data was loaded from input files!\n" 
        unless (keys %map_data) > 0;
    $args->{map_data} = \%map_data;
    return $args;
}

sub get_map_ids{
    my $args = shift;
    my @map_ids = sort{$a cmp $b} keys %{$args->{map_data}};
    return @map_ids;
}

sub get_LG_ids{
    my ($args, @map_ids) = @_;
    @map_ids = get_map_ids($args) unless @map_ids;
    my %LGs;
    for my $map_id (@map_ids){
        my @LG_keys = keys %{$args->{map_data}->{$map_id}};
        map{$LGs{$_}++} @LG_keys;
    }
    my @LGs = sort {$a cmp $b} keys %LGs;
    return @LGs;    
}

sub get_LG_hash{
    my ($args, $map_id, $LG) = @_;
    return %{$args->{map_data}->{$map_id}->{$LG}};
}

sub get_marker_ids{
    my ($args, $map_id, $LG) = @_;
    my %LG = %{$args->{map_data}->{$map_id}->{$LG}};
    my @marker_ids = sort {$LG{$a} <=> $LG{$b} or $a cmp $b} keys %LG;
    return @marker_ids;
}

sub get_common_marker_num{
    my ($args, $map_id1, $map_id2, @LGs) = @_;
    my $common_markers = 0;
    for my $LG (@LGs){
        unless($args->{map_data}->{$map_id1}->{$LG} and 
           $args->{map_data}->{$map_id2}->{$LG}){
            next;       
        }
        for my $marker (keys %{$args->{map_data}->{$map_id1}->{$LG}}){
            $common_markers++ if 
                exists $args->{map_data}->{$map_id2}->{$LG}->{$marker};
        }
    }
    return $common_markers;
}

#
# Blast data
#

sub load_blast_data{
    my $args = shift;
    my $blast_file = $args->{options}->{blast};
    die "# CAUTION: BLAST file is required!\n" unless $blast_file;

    my %blast_data;
    open my $blast_fh, $blast_file or die $!;
    while(<$blast_fh>){ 
        next if /^\s*$/ or /^\s*#/;
        @_ = split /\t/;
        next unless $_[3] =~ /^-?\d+(\.\d+)?$/;
        my $marker_name = $_[0];
        my $scf = $_[1];
        my ($start, $end) = @_[8,9];
        my $scf_pos = int( ($start + $end) / 2 );
        push @{$blast_data{$marker_name}}, [$scf, $scf_pos];
    }
    close $blast_fh;
    die "ERROR: No blast data was loaded!\n" 
        unless (keys %blast_data) > 0;
    return %blast_data;
}

#
# Bowtie data
# 

sub load_bowtie_data{
    my $args = shift;
    my $bowtie_file = $args->{options}->{bowtie};
    die "# CAUTION: Bowtie file is required!\n" unless $bowtie_file;

    my %bowtie_data;
    open my $bowtie_fh, $bowtie_file or die $!;
    while(<$bowtie_fh>){
        next if /^\s*$/ or /^\s*#/;
        chomp;
        my ($marker_name1, undef, $scf1, $scf_pos1) = split /\t/;
        $marker_name1 =~ s/\/\d$//;
        $_ = <$bowtie_fh>;
        chomp;
        my ($marker_name2, undef, $scf2, $scf_pos2) = split /\t/;
        $marker_name2 =~ s/\/\d$//;
        die unless $marker_name1 eq $marker_name2;
        die unless $scf1 eq $scf2;
        die unless abs($scf_pos1 - $scf_pos2) < 1000;
        my $middle = int(($scf_pos1 + $scf_pos2) / 2);
        push @{$bowtie_data{$marker_name1}}, [$scf1, $middle];
    }
    close $bowtie_fh;
    return %bowtie_data;
}

#
# Create bin markers
#

sub build_simple_network{
    # Input: @array = ([a, b], [b,c], [d, e], ...)
    # Output: @net = ([a, 0], [b, 0], [c, 0], [d, 1], [e, 1], ...)
    my @input = @_;
    my $first_pair = shift @input;
    my $net_index = 1;
    my %net;
    map{$net{$_} = $net_index} @$first_pair;
    for my $pair (@input){
        my ($id1, $id2) = @$pair;
        if(exists $net{$id1} and exists $net{$id2}){
            next;
        }
        elsif(exists $net{$id1} or exists $net{$id2}){
            if(exists $net{$id1}){
                $net{$id2} = $net{$id1};
            }
            else{
                $net{$id1} = $net{$id2};
            }
        }
        else{
            $net_index++;
            $net{$id1} = $net_index;
            $net{$id2} = $net_index;
        }
    }
    my @net = map {[$_, $net{$_}]} sort {$net{$a} <=> $net{$b}} keys %net;
    return @net;
}

sub new_bin_number{
    my $args = shift;
    my $max = max(values %{$args->{binmarker}});
    return $max + 1;
}

sub load_blastn_self_data{
    my $args = shift;
    return $args unless $args->{options}->{self};
    my @blastn_self_files = split(/,/, join(',', @{$args->{options}->{self}}));
    my @marker_pairs;
    for my $blastn_self_file (@blastn_self_files){
        open my $fh, $blastn_self_file or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            my ($marker1, $marker2) = split /\t/;
            push @marker_pairs, [$marker1, $marker2];
        }
        close $fh;
    }
    my @bin_markers = build_simple_network(@marker_pairs);
    for my $bin_marker (@bin_markers){
        my ($marker, $bin_number) = @$bin_marker;
        $args->{binmarker}->{$marker} = $bin_number;
    }
    return $args;
}

sub get_uniq_markers{
    my @window = @_;
    my @markers = map{$_->[2]}@window;
    my %markers = map {$_, 1} @markers;
    return sort {$a cmp $b} keys %markers;
}

sub print_conflicts{
    my ($args, @markers) = @_;
    for my $marker (@markers){
        if($args->{binmarker}->{$marker}){
            print "$marker\t",$args->{binmarker}->{$marker},"\n";
        }
    }
    return 1;
}

sub determine_bin_number{
    my ($args, @window) = @_;
    my @markers = get_uniq_markers(@window);
    #warn "Processing markers: @markers ...\n";
    my $bin_number;
    for my $marker (@markers){
        if(exists $args->{binmarker}->{$marker}){
            if($bin_number){
                unless($bin_number == $args->{binmarker}->{$marker}){
                    $args->{conflicts_count}++;
                    warn "### Conflict ", $args->{conflicts_count}, 
                        ": ", $args->{status}->{scaffold}, " @markers\n";
                    #print_conflicts($args, @markers);
                    return $args;
                }
            }
            else{
                $bin_number = $args->{binmarker}->{$marker};
            }
        }
    }
    unless($bin_number){
        $bin_number = new_bin_number($args);
    }
    for my $marker (@markers){
        $args->{binmarker}->{$marker} = $bin_number;
    }
    return $args;
}

sub analyze_blastn_scaffold_data{
    my $args = shift;
    my $window_count;
    my $window = $args->{options}->{window} // 10000;
    for my $scaffold ( keys %{$args->{blastn_data}}){
        $args->{status}->{scaffold} = $scaffold;
        my @arrays = sort{$a->[0] <=> $b->[0]
                         }@{$args->{blastn_data}->{$scaffold}};
        my @window;
        my $window_start;
        for my $array (@arrays){
            my ($start, $end, $marker) = @$array;
            if(@window == 0){
                push @window, $array;
                $window_start = $start;
            }
            elsif($end - $window_start <= $window){
                push @window, $array;
            }
            else{
                my @markers = get_uniq_markers(@window);
                if(@markers > 2){
                    $window_count++; 
                    #warn "Process window $window_count ...\n";
                    $args = determine_bin_number($args, @window);
                }
                @window = ();
                $window_start = undef;
            }
        }
    }
    return $args;
}

sub load_blastn_scaffold_data{
    # Blastn data structure
    # $args->{blastn_data}->{$scaffold} = ([$start, $end, $marker], ...)
    
    my $args = shift;
    return $args unless $args->{options}->{blastn};
    my @blastn_files =  split(/,/,join(',', @{$args->{options}->{blastn}}));
    for my $blastn_file (@blastn_files){
        open my $fh, $blastn_file or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            my($marker, $scaffold, $start, $end) = (split /\t/)[0,1,8,9];
            ($start, $end) = ($end, $start) unless $start <= $end;
            push @{$args->{blastn_data}->{$scaffold}}, [$start, $end, $marker];
        }
        close $fh;
    }
    
    $args = analyze_blastn_scaffold_data($args);
    return $args;
}

sub print_bin_markers{
    my $args = shift;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids($args, $map_id);
        for my $LG (@LGs){
            my @markers = get_marker_ids($args, $map_id, $LG);
            for my $marker(@markers){
                if(exists $args->{binmarker}->{$marker}){
                    my $genetic_pos = 
                        $args->{map_data}->{$map_id}->{$LG}->{$marker};
                    my $binmarker = sprintf "Bin%06d",
                        $args->{binmarker}->{$marker};
                    print join("\t", $map_id, $LG, $marker, $genetic_pos,
                        $binmarker)."\n";
                }
            }
        }
    }
}

sub _remove_conflict_bin_markers_LG{
    my ($args, $map_id, $LG) = @_;
    my %LG = %{$args->{map_data}->{$map_id}->{$LG}};
    
    my %seen;
    my %conflicts;
    for my $marker(keys %LG){
        if(exists $args->{binmarker}->{$marker}){
            if($seen{$args->{binmarker}->{$marker}}){
                $conflicts{$args->{binmarker}->{$marker}} = 1;
            }
            else{
                $seen{$args->{binmarker}->{$marker}} = 1;
            }
        }
    }
    
    for my $marker (keys $args->{binmarker}){
        if($conflicts{$args->{binmarker}->{$marker}}){
            delete $args->{binmarker}->{$marker};
        }
    }
    return $args;
}

sub remove_conflict_bin_markers{
    my $args = shift;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            _remove_conflict_bin_markers_LG($args, $map_id, $LG);
        }
    }
    return $args;
}

sub remove_solo_bin_markers{
    my $args = shift;
    my @map_ids = get_map_ids $args;
    my %count;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            my %LG = get_LG_hash $args, $map_id, $LG;
            for my $marker (keys %LG){
                if(exists $args->{binmarker}->{$marker}){
                    $count{$args->{binmarker}->{$marker}}++;
                }
            }
        }
    }
    
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            my %LG = get_LG_hash $args, $map_id, $LG;
            for my $marker (keys %LG){
                if(exists $args->{binmarker}->{$marker}){
                    delete $args->{binmarker}->{$marker} if 
                        $count{$args->{binmarker}->{$marker}} == 1;
                }
            }
        }
    }
    
    return $args;
}

sub print_merged_marker_set{
    my $args = shift;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids($args, $map_id);
        for my $LG (@LGs){
            my @markers = get_marker_ids($args, $map_id, $LG);
            for my $marker (@markers){
                my $genetic_pos = 
                    $args->{map_data}->{$map_id}->{$LG}->{$marker};
                print join("\t", $map_id, $LG, $marker, $genetic_pos)."\n";
                if(exists $args->{binmarker}->{$marker}){
                        my $binmarker = sprintf "Bin%06d",
                            $args->{binmarker}->{$marker};
                        print join("\t", $map_id, $LG, 
                            $binmarker, $genetic_pos)."\n";
                }
            }
        }
    }
}

sub binmarkers{
    my $args = new_action(
        -desc => 'Create bin markers for SNPs',
        -options => {
            "blastn|b=s@" => 'Blastn file of SNP flanking sequence 
                              against scaffolds [could be multiple]',
            "self|s=s@" => 'Blastn file of SNP flanking sequence 
                            against SNP flanking sequence [could be multiple]',
            "window|w=i" => 'Bin marker window size [default: 10000]',
            "print|p"    => 'Print bin markers only[default: all markers]',
            "remove|r"   => 'Remove conflict bin markers'
        }
    );
    die "WARNING: blastn files are required!\n" 
        unless $args->{options}->{blastn} or $args->{options}->{self};
        
    $args = load_map_data2($args);
    $args = load_blastn_self_data($args);
    $args = load_blastn_scaffold_data($args);
    if($args->{options}->{remove}){
        $args = remove_conflict_bin_markers($args);
        $args = remove_solo_bin_markers($args);
    }
    if($args->{options}->{print}){
        print_bin_markers($args);
    }
    else{
        print_merged_marker_set($args);
    }

    return 1;
}


#
# Create ALLMAPS file
#

sub write_allmaps_file{
    my ($map_data_ref, $physical_data_ref) = @_;
    my %map_data = %$map_data_ref;
    my %physical_data = %$physical_data_ref;

    for my $map_id (keys %map_data){
        my $outfile = "allmaps-input-$map_id.csv";
        open my $fh, ">", $outfile or die $!;
        print $fh "Scaffold ID,scaffold position,LG,genetic position\n";
        for my $marker_name (keys %{$map_data{$map_id}}){
             next unless $physical_data{$marker_name};
             for my $pos_ref (@{$physical_data{$marker_name}}){
                 my ($scf, $scf_pos) = @$pos_ref;
                 my ($LG, $genetic_pos) = @{$map_data{$map_id}->{$marker_name}};
                 #$genetic_pos = sprintf "%.1f", $genetic_pos;
                 print $fh "$scf,$scf_pos,$LG,$genetic_pos\n";
             }
        }
        close $fh;
        warn "Done! Output data in file: $outfile\n";
    }
    return 1;
}

#
# Convert input data to the format ALLMAPS required
#

sub blastn2allmaps{
    my $args = new_action(
        -desc => 'Prepare input data for allmaps',
        -options => {
            "blast|b=s" => 'BLAST file: SNP flanking sequence against 
                            genome (blastn -outfmt 6 -perc_identity 95)'
        }
    );

    my %map_data   = load_map_data($args);
    my %blast_data = load_blast_data($args);

    write_allmaps_file(\%map_data, \%blast_data);
}

sub bowtie2allmaps{
    my $args = new_action(
        -desc => 'Prepare input data for allmaps',
        -options => {
            "bowtie|b=s" => 'Bowtie file: SSR primers 
             (bowtie -f -v 2 -I 30 -X 600)'
        }
    );
    my %map_data = load_map_data($args);
    my %bowtie_data = load_bowtie_data($args);

    write_allmaps_file(\%map_data, \%bowtie_data);
}

# 
# Convert input data to the format MergeMap required
#

sub mergemap{
    my $args = new_action(
        -desc => 'Prepare input data for mergemap'
    );

    $args = load_map_data2($args);
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        open my $fh, ">", "mergemap-input-$map_id.map" or die $!;
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            print $fh "group $LG\n";
            print $fh ";BEGINOFGROUP\n";
            for my $marker_name (keys %{$args->{map_data}->{$map_id}->{$LG}}){
                my $genetic_pos = 
                    $args->{map_data}->{$map_id}->{$LG}->{$marker_name};
                print $fh "$marker_name\t$genetic_pos\n";
            }
            print $fh ";ENDOFGROUP\n";
        }
        close $fh;
    }
}

#
# Run MergeMap LG-by-LG
# 

sub mergemapLG{
    my $args = new_action(
        -desc => 'Prepare input data for mergemap LG-by-LG'
    );

    $args = load_map_data2($args);
    my %maps_config;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            my $outfile = "mergemap-input-LG_$LG-$map_id.map";
            push @{$maps_config{$LG}}, $outfile;
            open my $fh, ">", $outfile or die $!;
            print $fh "group $LG\n";
            print $fh ";BEGINOFGROUP\n";
            my %hash = %{$args->{map_data}->{$map_id}->{$LG}};
            for my $marker (sort {$hash{$a} <=> $hash{$b}} keys %hash){
                my $LG_pos = sprintf "%.1f", $hash{$marker};
                print $fh "$marker\t$LG_pos\n";
            }
            print $fh ";ENDOFGROUP\n";
            close $fh;
        }
    }

    for my $LG (sort {$a cmp $b} keys %maps_config){
        my $config_file = "mergemap-input-LG_$LG.maps_config";
        open my $fh, ">", $config_file or die $!;
        my $index = 0;
        for my $outfile (@{$maps_config{$LG}}){
            print $fh "map$index 1  $outfile\n";
            $index++;
        }
        close $fh;
    }

    open my $shell_fh, ">", "mergemap-commands.sh" or die $!;
    print $shell_fh 
'#!/bin/sh
set -x
for i in $(ls mergemap-input-LG_*.maps_config)
do
    consensus_map.exe $i
    for j in lg0.dot lg0_consensus.dot lg0_linear.dot linear_map_chart.txt
    do
        mv $j $i-$j
    done
done

for i in $(ls *.dot)
do
    dot -Tpng $i > $i.png
done

';
    close $shell_fh;
}

# 
# Convert data in multiple linear_map_chart.txt files into the 
# 4-column format
#

sub linear_map_chart{
    my $args = new_action(
        -desc => 'Read linear_map_chart.txt files'
    );

    my @infiles = @{$args->{infiles}};
    my @in_fhs  = @{$args->{in_fhs}};
    for(my $i = 0; $i <= $#infiles; $i++){
        my $infile = $infiles[$i];
        my $in_fh  = $in_fhs[$i];
        my $group;
        while(<$in_fh>){
            next if /^\s*$/ or /^\s*;/;
            if (/^group\s+(\S+)/){
                $group = $1;
            }
            elsif(/^(\S+)\s+(-?\d+(\.\d+)?)/){
                my ($marker_info, $pos) = ($1, $2);
                die "CAUTION: Group number is unknown!" unless $group;
                my @markers = split /,/, $marker_info;
                for my $marker (@markers){
                    print "$infile\t$group\t$marker\t$pos\n";
                }
            }
            else{
                die "CAUTION: $_";
            }
        }
    }
}

#
# Common markers statistics
#

sub commonstats_default{
    my $args = shift;
    my $print_map_number = $args->{options}->{number};
    my @map_ids = get_map_ids($args);
    my @LGs = get_LG_ids($args);
    print join ("\t", "map1", "map2", "LG", "Common_markers",               
                       "(Markers_in_map1,Markers_in_map2)"
                    )."\n";
                    
    for(my $i = 0; $i <= $#map_ids - 1; $i ++){
        for (my $j = $i; $j <= $#map_ids; $j++){
            next if $print_map_number and $j != $i;
            for my $LG (@LGs){
                    my $map1 = $map_ids[$i];
                    my $map2 = $map_ids[$j];
                    my $common_markers = get_common_marker_num(
                              $args, $map1, $map2, $LG);
                    my $markers_in_map1 = 
                        keys %{$args->{map_data}->{$map1}->{$LG}};
                    my $markers_in_map2 = 
                        keys %{$args->{map_data}->{$map2}->{$LG}};
                    print join("\t", $map1, $map2, "LG$LG", $common_markers,
                        "($markers_in_map1,$markers_in_map2)")."\n";
            }
        }
    }
}

sub commonstats_matrix_mode{
    my $args = shift;
    my $print_map_number = $args->{options}->{number};
    my @map_ids = get_map_ids($args);
    my @LGs = get_LG_ids($args);
    # Print title
    print join("\t", "map1", "map2", map{"LG$_"}@LGs)."\n";

    # Print data
    for(my $i = 0; $i <= $#map_ids - 1; $i ++){
        for (my $j = $i; $j <= $#map_ids; $j++){
            next if $print_map_number and $j != $i;
            my $map1 = $map_ids[$i];
            my $map2 = $map_ids[$j];
            my @common_markers = map{get_common_marker_num(
                    $args, $map1, $map2, $_
                )}@LGs;
            print join("\t", $map1, $map2, @common_markers)."\n";
        }
    } 
}

sub commonstats_symm_LG_mode{
    my $args = shift;
    my @map_ids = get_map_ids($args);
    my @LGs = get_LG_ids($args);
    
    for my $LG (@LGs, "all_LGs"){
        # Print title
        print "=" x 60, "\n";
        print join("\t", "LG-$LG", @map_ids)."\n";
        for(my $i = 0; $i <= $#map_ids; $i++){
            my $map1 = $map_ids[$i];
            if($LG eq 'all_LGs'){
                print join("\t", $map1, map{
                    get_common_marker_num($args, $map1, $_, @LGs)
                    }@map_ids)."\n";
            }
            else{
                print join("\t", $map1, map{
                    get_common_marker_num($args, $map1, $_, $LG)
                    }@map_ids)."\n";
            }
        }
    }
    return 0;
}

sub commonstats{
    my $args = new_action(
        -desc => 'Count common markers between different maps',
        -options => {
            "matrix|m" => 'Matrix mode -- one LG per column. Not compatible 
                           with --LG
                          [Default: line mode -- one datum per line]',
            "number|n" => 'Print number of markers for each LG each map, only
                           valid with the option --matrix',
            "LG|L|l"   => 'Print common markers matrix LG-by-LG. Not compatible
                           with --matrix'
        }
    );
    my $matrix_mode = $args->{options}->{matrix};
    my $symm_LG_mode = $args->{options}->{LG};
    $args = load_map_data2($args);

    if($matrix_mode){
        # Row is map pair
        # Column is LG number
        commonstats_matrix_mode($args)
    }
    elsif($symm_LG_mode){
        # Multiple matrix, one per LG
        # For each matrix, row is map ID, column is map ID
        commonstats_symm_LG_mode($args);
    }
    else{
        # map1 map2 LG common_number ...
        commonstats_default($args)
    }
}

#
# Summary of maps
#

sub summarymap{
    my $args = new_action(
        -desc => 'Summary of map data',
        -options => {
            "title|t" => 'Print title [Default: no title]',
            "LG|L|l" => 'Summarize data LG by LG'
        }
    );
    my $print_title = $args->{options}->{title};
    my $LG_mode = $args->{options}->{LG};
    $args = load_map_data2($args);
    my @map_ids = get_map_ids($args);
    if ($LG_mode){
        # Print title
        print join("\t", "Map ID", "LG", "Number of markers", 
                        "Length", "Average intervals", 
                        "LG start", "LG end")."\n" 
                if $print_title;
        for my $map_id (@map_ids){
            my @LGs = get_LG_ids($args, $map_id);
            for my $LG (@LGs){
                my $num_markers = keys %{$args->{map_data}->{$map_id}->{$LG}};
                my ($LG_start, $LG_end) = (sort {$a <=> $b} 
                    values %{$args->{map_data}->{$map_id}->{$LG}})[0,-1];
                my $length = sprintf "%.1f", $LG_end - $LG_start;
                my $average_intervals = $num_markers > 1 ? 
                    sprintf "%.2f", $length / ($num_markers - 1) :
                    "NA";
                print join("\t", $map_id, "LG$LG", $num_markers, 
                    $length, $average_intervals, $LG_start, $LG_end)."\n";
            }
        }
    }
    else{
    # Print title
    print join("\t", "Map ID", "Number of LGs", 
        "Number of markers", "Total length")."\n" if $print_title;
    for my $map_id (@map_ids){
        my $num_LG;
        my $num_markers;
        my $length;
        my @LGs = get_LG_ids($args, $map_id);
        for my $LG (@LGs){
            $num_LG++;
            $num_markers += keys %{$args->{map_data}->{$map_id}->{$LG}};
            my @positions = sort {$a <=> $b} 
                values %{$args->{map_data}->{$map_id}->{$LG}};
            $length += $positions[-1] - $positions[0];
        }
        $length = sprintf "%.1f", $length;
        print "$map_id\t$num_LG\t$num_markers\t$length\n";
    }
    }
}

sub drawfigureR{
    print '
pdf("y_figure.pdf")
map <- read.table("y_data.markers.txt")
par(mar=c(5,5,1,1),family="serif",font=2,cex.lab=1.5,cex.axis=1)
plot(map$V1,map$V2,col=map$V3,pch=95,axes=F,xlab="Linkage group number",ylab="Genetic distance",type="n",,cex=1.2,cex.lab=1)
segments(map$V1-0.3,map$V2,map$V1+0.3,map$V2,lwd=1,col=map$V3)
for (i in 1:17){y1<-map$V2[map$V1==i];n<-length(y1);lines(rep(i,n),y1,lwd=1)}
axis(side=1,at=0:17,tick=-0.1,lwd=2,labels=0:17)
axis(side=2,at=c(-8,seq(0,500,20)),tick=-0.1,labels=c("",seq(0,500,20)),lwd=2)
dev.off()
';
    exit;
}

sub input4R{
    my $args = new_action(
        -desc => 'Get input data for R codes',
        -options => {
            "mode|m=s" => 'color mode, ssr or bin: 
                         ssr (=red, others = black);  
                         bin (= red, others = black). Default: ssr'
        }
    );
    my $mode = $args->{options}->{mode} // 'ssr';
    
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            my ($map_id, $LG, $marker, $LG_pos) = split /\t/;
            my $color;
            if($mode =~ /^s(sr)?$/i){
                $color = "red";
                $color = 'black' if $marker =~ /^JPsnp|^Py|^ss|^TsuSNP|^Bin/;
            }
            elsif($mode =~ /^b(in)?$/i){
                $color = 'black';
                $color = 'blue' if $marker =~ /^Bin/;
            }
            else{die "Color mode ERROR: $mode!!!\n"}
            print join("\t", $LG, $LG_pos, $color)."\n";
        }
    }
}

sub consensus2allmaps{
    my $args = new_action(
        -desc => 'Prepare data for ALLMAPS using consensus map',
        -options => {
            "scaffold|s=s" => 'alignment of markers against scaffold sequences,
            [marker,scaffold,start,end]'
        }
    );
    die "CAUTION: -s is required!\n" unless $args->{options}->{scaffold};
    
    $args = load_map_data2 $args;
    my %consensus_map;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            my %LG = %{$args->{map_data}->{$map_id}->{$LG}};
            for my $marker (keys %LG){
                my $genetic_pos = $LG{$marker};
                push @{$consensus_map{$marker}}, [$map_id, $LG, $genetic_pos];
            }
        }
    }
    warn "Number of markers: ".
         (keys %consensus_map)."\n";
    warn "Number of duplicated markers: ".
         (grep {@{$consensus_map{$_}} > 1} keys %consensus_map)."\n";
    warn "Number of uniq markers: ".
         (grep {@{$consensus_map{$_}} == 1} keys %consensus_map)."\n";   

    my $num_aln = 0;
    my $valid_aln = 0;
    my $aln_scaffold = $args->{options}->{scaffold};
    open my $aln_fh, $aln_scaffold or die $!;
    while(<$aln_fh>){
        $num_aln++;
        chomp;
        my ($marker, $scaffold, $start, $end) = split /\t/;
        my $scf_pos = int(($start + $end) / 2);
        next unless exists $consensus_map{$marker};
        next if @{$consensus_map{$marker}} > 1;
        my ($map_id, $LG, $genetic_pos) = @{$consensus_map{$marker}->[0]};
        print "$scaffold,$scf_pos,$LG,$genetic_pos\n";
        $valid_aln++;
    }
    close $aln_fh;
    warn "Number of alignments: $num_aln\n";
    warn "Number of valid alignments: $valid_aln\n";
}

__END__
