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
    summaryLG        | Summary of input data
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
    die "ERROR: No map data was loaded from input files!\n" 
        unless (keys %map_data) > 0;
    return %map_data;
}

sub get_all_LG_ids{
    my %map_data = @_;
    my %LGs;
    for my $map_id (keys %map_data){
        for my $marker_name (keys %{$map_data{$map_id}}){
            my ($LG, $genetic_pos) = @{$map_data{$map_id}->{$marker_name}};
            $LGs{$LG}++;
        }
    }
    my @LGs = sort {$a cmp $b} keys %LGs;
    return @LGs;
}

sub get_common_marker_num{
    my ($map_data_ref, $map_id1, $map_id2, $LG_ref) = @_;
    my %map_data = %$map_data_ref;
    my @LGs = @$LG_ref;
    my @markers1 = keys %{$map_data{$map_id1}};
    my @markers2 = keys %{$map_data{$map_id2}};
    my %count;
    for my $marker_name (keys %{$map_data{$map_id1}}){
        if ($map_data{$map_id2}->{$marker_name} and 
            $map_data{$map_id1}->{$marker_name}->[0] eq
            $map_data{$map_id2}->{$marker_name}->[0]){
            $count{$map_data{$map_id1}->{$marker_name}->[0]}++;
        }
    }
    return map{$count{$_} // 0}@LGs;
}

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


sub commonstats{
    my $args = new_action(
        -desc => 'Count common markers between different maps'
    );
    my %map_data = load_map_data($args);
    my @map_ids  = sort {$a cmp $b} keys %map_data;
    my @LGs = get_all_LG_ids(%map_data);
    print "map1\tmap2\t", join("\t", map{"LG$_"}@LGs), "\n";
    for(my $i = 0; $i <= $#map_ids - 1; $i ++){
        for (my $j = $i + 1; $j <= $#map_ids; $j++){
            my $map1 = $map_ids[$i];
            my $map2 = $map_ids[$j];
            my @num_markers = get_common_marker_num(
                              \%map_data, $map1, $map2, \@LGs);
            print "$map1\t$map2\t", join("\t", @num_markers),"\n";
        }
    }
}

sub summary_map{
    my ($map_data_ref, $map_id, $LGs) = @_;
    my %markers = %{$map_data_ref->{$map_id}};
    my @LGs = @$LGs;
    my $total_markers = keys %markers;
    my %num_markers;
    my %LG_length = map{($_, 0)}@LGs;
    my %LG_pos_array;
    for my $marker (keys %markers){
        my ($LG, $genetic_pos) = @{$markers{$marker}};
        $num_markers{$LG}++;
        push @{$LG_pos_array{$LG}}, $genetic_pos;
        if($genetic_pos > $LG_length{$LG}){
            $LG_length{$LG} = $genetic_pos;
        }
    }
    for my $LG (keys %LG_pos_array){
        my @array = @{$LG_pos_array{$LG}};
        my ($min, $max) = (sort {$a <=> $b}@array)[0, -1];
        $LG_length{$LG} = $max-$min;
    }

    my $total_length = sum(values %LG_length);
    return ($total_markers, $total_length, 
        map{($num_markers{$_} // 0, $LG_length{$_})}@LGs
    );
}

sub summaryLG{
    my $args = new_action(
        -desc => 'Summary of input data'
    );
    my %map_data = load_map_data($args);
    my @LGs = get_all_LG_ids(%map_data);

    print "map_ID\tTotal_markers\tTotal_Length\t",
          join("\t", map{("Num_markers-LG_$_","Length-LG_$_")}@LGs), "\n";
    for my $map_id (sort {$a cmp $b}keys %map_data){
        my ($total_markers, $total_length, @LG_summary) = 
            summary_map(\%map_data, $map_id, \@LGs);
        print join ("\t", $map_id, $total_markers, $total_length, @LG_summary), "\n";
    }
}

sub summary_map3{
    my ($map_data_ref, $map_id) = @_;
    my @pos_ref;
    for my $marker_name (keys %{$map_data_ref->{$map_id}}){
        push @pos_ref, $map_data_ref->{$map_id}->{$marker_name};
    }

    my ($num_markers, $num_LG, $length) = (0, 0, 0);
    my %LG;
    for my $pos_info (@pos_ref){
        $num_markers++;
        my ($LG, $pos) = @$pos_info;
        $LG{$LG}->{$pos}++;
    }
    $num_LG = scalar(keys %LG);
    for my $LG (keys %LG){
        my @pos_array = sort {$a <=> $b} keys %{$LG{$LG}};
        $length += $pos_array[-1] - $pos_array[0];
    }
    $length = sprintf "%.1f", $length;
    return ($num_markers, $num_LG, $length);
}

sub summarymap{
    my $args = new_action(
        -desc => 'Summary of map data'
    );
    my %map_data = load_map_data($args);
    for my $map_id (sort {$a cmp $b} keys %map_data){
        my ($num_markers, $num_LG, $length) = summary_map3(\%map_data,$map_id);
        print "$map_id\t$num_LG\t$num_markers\t$length\n";
    }
}

__END__
