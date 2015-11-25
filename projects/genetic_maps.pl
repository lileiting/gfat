#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw(sum);
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

    Space was not allowed in map_ID, and marker_name,
    LG should be integer only

Availabe actions
    blastn2allmaps   | Prepare input data for allmaps
    bowtie2allmaps   | Prepare input data for allmaps
    mergemap         | Prepare input data for mergemap
    mergemapLG       | one file per LG 
    commonstats      | Count common markers
    summarymap       | Summary of input data
    linear_map_chart | read linear_map_chart files

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

sub load_map_data{
    my $args = shift;
    my %map_data;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            unless(/^(\S+)\t(\S+)\t(\d+)\t(-?\d+(\.\d+)?)$/){
                warn "Ignore: $_\n";
                next;
            }
            my ($map_id, $marker_name, $LG, $genetic_pos)
                = ($1, $2, $3, $4);
            die "Duplicated marker: $marker_name!!!\n" 
                if $map_data{$map_id}->{$marker_name};
            $map_data{$map_id}->{$marker_name} = [$LG, $genetic_pos];
        }
    }
    die "[load_map_data] ERROR: No map data was loaded from input files!\n" 
        unless (keys %map_data) > 0;
    return %map_data;
}

sub load_map_data2{
    my $args = shift;
    my %map_data;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            unless(/^(\S+)\t(\S+)\t(\d+)\t(-?\d+(\.\d+)?)$/){
                warn "Ignore: $_\n";
                next;
            }
            my ($map_id, $marker_name, $LG, $genetic_pos)
                = ($1, $2, $3, $4);
            die "Duplicated marker: $marker_name!!!\n" 
                if $map_data{$map_id}->{$marker_name};
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
    my $args = shift;
    my @map_ids = get_map_ids($args);
    my %LGs;
    for my $map_id (@map_ids){
        my @LG_keys = keys %{$args->{map_data}->{$map_id}};
        map{$LGs{$_}++} @LG_keys;
    }
    my @LGs = sort {$a <=> $b} keys %LGs;
    return @LGs;    
}

sub get_common_marker_num{
    my ($args, $map_id1, $map_id2, $LG) = @_;
    unless($args->{map_data}->{$map_id1}->{$LG} and 
           $args->{map_data}->{$map_id2}->{$LG}){
        return 0;       
    }
    
    my $common_markers = 0;
    for my $marker (keys %{$args->{map_data}->{$map_id1}->{$LG}}){
        $common_markers++ if $args->{map_data}->{$map_id2}->{$LG}->{$marker};
    }

    return $common_markers;
}

sub get_common_marker_num_multiple_LGs{
    my ($args, $map_id1, $map_id2, @LGs) = @_;
    my $common_elements = 0;
    for my $LG(@LGs){
        $common_elements += get_common_marker_num(
            $args, $map_id1, $map_id2, $LG);
    }
    return $common_elements;
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

    my %map_data = load_map_data($args);
    for my $map_id (keys %map_data){
        my %hash;
        open my $fh, ">", "mergemap-input-$map_id.map" or die $!;
        for my $marker_name (keys %{$map_data{$map_id}}){
            my ($LG, $genetic_pos) = @{$map_data{$map_id}->{$marker_name}};
            push @{$hash{$LG}}, [$genetic_pos, $marker_name];
        }
        for my $LG (sort {$a cmp $b} keys %hash){
            print $fh "group $LG\n";
            print $fh ";BEGINOFGROUP\n";
            for my $pos_info (sort {$a->[0] <=> $b->[0]} @{$hash{$LG}}){
                my ($genetic_pos, $marker_name) = @$pos_info;
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

    my %map_data = load_map_data($args);
    my %maps_config;
    for my $map_id (keys %map_data){
        my %hash;
        #open my $fh, ">", "mergemap-input-$map_id.map" or die $!;
        for my $marker_name (keys %{$map_data{$map_id}}){
            my ($LG, $genetic_pos) = @{$map_data{$map_id}->{$marker_name}};
            push @{$hash{$LG}}, [$genetic_pos, $marker_name];
        }
        
        for my $LG (sort {$a cmp $b} keys %hash){
            my $outfile = "mergemap-input-LG_$LG-$map_id.map";
            push @{$maps_config{$LG}}, $outfile;
            open my $fh, ">", $outfile or die $!;
            print $fh "group $LG\n";
            print $fh ";BEGINOFGROUP\n";
            for my $pos_info (sort {$a->[0] <=> $b->[0]} @{$hash{$LG}}){
                my ($genetic_pos, $marker_name) = @$pos_info;
                print $fh "$marker_name\t$genetic_pos\n";
            }
            print $fh ";ENDOFGROUP\n";
            close $fh;
        }
        #close $fh;
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
dir='.$FindBin::RealBin.'
for i in $(ls mergemap-input-LG_*.maps_config)
do
    $dir/consensus_map.exe $i
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
                    get_common_marker_num_multiple_LGs($args, $map1, $_, @LGs)
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
            "matrix|m" => 'Matrix mode -- one LG per column. 
                          [Default: line mode -- one datum per line]',
            "number|n" => 'Print number of markers for each LG each map',
            "LG|L|l"   => 'Print common markers matrix LG-by-LG'
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
    my @map_ids = sort{$a cmp $b} keys %{$args->{map_data}};
    if ($LG_mode){
        # Print title
        print join("\t", "Map ID", "LG", "Number of markers", 
                        "Length", "Average intervals", 
                        "LG start", "LG end")."\n" 
                if $print_title;
        for my $map_id (@map_ids){
            my @LGs = sort {$a <=> $b} keys %{$args->{map_data}->{$map_id}}; 
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
    for my $map_id (sort {$a cmp $b} keys %{$args->{map_data}}){
        my $num_LG;
        my $num_markers;
        my $length;
        for my $LG (keys %{$args->{map_data}->{$map_id}}){
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

__END__
