#!/usr/bin/env perl

############################################################
# Toolkit to analyse genetic map data                      #
############################################################

use warnings;
use strict;
use FindBin;
use List::Util qw(sum max min);
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

#~~~~~~~~~~~~~~~~~~~~~~~~ Main usage ~~~~~~~~~~~~~~~~~~~~~~#

sub main_usage{
    print <<"usage";

Usage
    $FindBin::Script ACTION [OPTIONS]

Description
    Manipulate genetic map data
    Default genetic map input data format is 4-column

    map_ID    LG    marker_name    genetic_pos

    Space was not allowed in map_ID and marker_name

Availabe actions

Run ALLMAPS
    blastn2allmaps   | Prepare input data for allmaps
    bowtie2allmaps   | Prepare input data for allmaps

Run MergeMap
    mergemap         | Prepare input data for mergemap
    mergemapLG       | one file per LG 

Analyse map-data (4-column)
    commonstats      | Count common markers
    summarymap       | Summary of input data
    conflicts        | Print conflicts
    remove_redundant | Remove redundant markers that in the same map location
    list_commons     | list common markers

Analyse MapChart-style data
    linear_map_chart | read linear_map_chart files
    report           | Report merged genetic map
    consensus2allmaps| Convert consensus map data as ALLMAPS input format 

Draw genetic map figure
    input4R          | Get input data for R codes
    drawfigureR      | print R codes for drawing genetic map figure

Draw Circos figure
    karyotype        | Prepare karyotype for circos figures

Draw dotplot
    mareymap         | Creating input data for MareyMap to draw draw dotplot 
                       for genetic map and physical map using MareyMap. 

Create bin markers:
    binmarkers       | Find bin markers, very complicated method, deprecated

Find bin markers based positions on scaffolds, greedy method
    convert_aln      |  Convert blastn or bowtie results data to a 4-column data
                        MARKER  SCAFFOLD  START  END
    greedy           | Creating bin markers
    annotate_binmarkers

usage
    exit;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~ Main ~~~~~~~~~~~~~~~~~~~~~~~~~~~#

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
# Definition of the 4-column map data structure            
# 1. map ID
# 2. LG
# 3. marker name
# 4. genetic position
############################################################

# load_map_data
# get_map_ids
# get_LG_ids
# get_markers_hash
# get_marker_names
# get_genetic_pos
# get_LG_indexed_map_data
# get_common_marker_number

sub load_map_data{
    my ($args, @map_files) = @_;
    my @fhs = get_in_fhs $args;
    for my $map_file (@map_files){
        open my $map_fh, "<", $map_file or die $!;
        push @fhs, $map_fh;
    }
    for my $fh (@fhs){
        while(<$fh>){
            chomp;
            unless(/^(\S+)\t(\S+)\t(\S+)\t(-?\d+(\.\d+)?)\b/){
                warn "[load_map_data] WARNING: $_\n";
                next;
            }
            my ($map_id, $LG, $marker_name, $genetic_pos)
                = ($1, $2, $3, $4);
            die "Duplicated marker: $marker_name!!!\n" 
                if exists $args->{map_data}->{$map_id}->{$LG}->{$marker_name};
            $args->{map_data}->{$map_id}->{$LG}->{$marker_name} = $genetic_pos;
        }
    }
    die "[load_map_data] ERROR: No map data was loaded from input files!\n" 
        unless (keys %{$args->{map_data}}) > 0;
    return $args;
}

sub get_map_ids{
    my $args = shift;
    my @map_ids = sort{$a cmp $b} keys %{$args->{map_data}};
    return @map_ids;
}

sub is_number{
    my @items = @_;
    map{return 0 unless /^-?\d+(\.\d+)?$/}@items;
    return 1;
}

sub is_scaffold_name{
    my @items = @_;
    map{return 0 unless /^\S+?\d+(\.\d+)?$/}@items;
    return 1;
}

sub sort_by_scaffold_number{
    my @items = @_;
    my @sorted;
    for my $item (@items){
        die unless $item =~ /^(\S+?)(\d+(\.\d+)?)$/;
        push @sorted, [$1, $2];
    }
    @sorted = sort {$a->[1] <=> $b->[1]}@sorted;
    @items = map{join "", @$_}@sorted;
    return @items;
}

sub get_LG_ids{
    my ($args, @map_ids) = @_;
    @map_ids = get_map_ids($args) unless @map_ids;
    my %LGs;
    for my $map_id (@map_ids){
        my @LG_keys = keys %{$args->{map_data}->{$map_id}};
        map{$LGs{$_}++} @LG_keys;
    }
    my @LGs = keys %LGs;
    if(is_number @LGs){
        @LGs = sort{$a <=> $b}@LGs;
    }
    elsif(is_scaffold_name @LGs){
        @LGs = sort_by_scaffold_number @LGs;
    }
    else{
        @LGs = sort{$a cmp $b}@LGs;
    }
    
    return @LGs;    
}

sub get_markers_hash{
    my ($args, $map_id, $LG) = @_;
    die qq/CAUTION: Undefined hash for map "$map_id" and LG "$LG"!/
        unless exists $args->{map_data}->{$map_id}->{$LG};
    return %{$args->{map_data}->{$map_id}->{$LG}};
}

sub get_marker_names{
    my ($args, $map_id, $LG) = @_;
    my %LG = %{$args->{map_data}->{$map_id}->{$LG}};
    my @marker_ids = sort {$LG{$a} <=> $LG{$b} or $a cmp $b} keys %LG;
    return @marker_ids;
}

sub get_genetic_pos{
    my ($args, $map_id, $LG, $marker_name) = @_;
    return $args->{map_data}->{$map_id}->{$LG}->{$marker_name};   
}

sub get_LG_indexed_map_data{
    my $args = shift;
    my %LG_indexed_map_data;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG(@LGs){
            $LG_indexed_map_data{$LG}->{$map_id} = 
                $args->{map_data}->{$map_id}->{$LG};
        }
    }
    return %LG_indexed_map_data;
}

sub get_marker_indexed_map_data{
    my $args = shift;
    my %marker_indexed_map_data;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            my %hash = get_markers_hash $args, $map_id, $LG;
            for my $marker (keys %hash){
                my $genetic_pos = $hash{$marker};
                die "Error for marker $marker!!!"
                    if exists $marker_indexed_map_data{$marker}->{$map_id};
                $marker_indexed_map_data{$marker}->{$map_id} = 
                    [$map_id, $LG, $genetic_pos];
            }
        }
    }
    return %marker_indexed_map_data;
}

sub get_common_marker_num{
    my ($args, $map_id1, $map_id2, @LGs) = @_;
    my $common_markers = 0;
    for my $LG (@LGs){
        unless(exists $args->{map_data}->{$map_id1}->{$LG} and 
           exists $args->{map_data}->{$map_id2}->{$LG}){
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
    die "# CAUTION: BLAST file is required!" unless $blast_file;

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
    die "ERROR: No blast data was loaded!" 
        unless (keys %blast_data) > 0;
    return %blast_data;
}

#
# Bowtie data
# 

sub load_bowtie_data{
    my $args = shift;
    my $bowtie_file = $args->{options}->{bowtie};
    die "# CAUTION: Bowtie file is required!" unless $bowtie_file;

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
            my @markers = get_marker_names($args, $map_id, $LG);
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
            my %LG = get_markers_hash $args, $map_id, $LG;
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
            my %LG = get_markers_hash $args, $map_id, $LG;
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
            my @markers = get_marker_names($args, $map_id, $LG);
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
    die "WARNING: blastn files are required!" 
        unless $args->{options}->{blastn} or $args->{options}->{self};
        
    $args = load_map_data($args);
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
        -desc => 'Prepare input data for mergemap',
        -options => {
            "number|n=i" => 'Suppress LGs with number of markers less than 
                            NUM (default: disable)',
            "length|l=i" => 'Supress LGs with length less than 
                             the threshold (cM) (default: disable)',
            "interval|i=f" => 'Supress LGs with average marker intervals 
                               greater than the threshold (default: disable)',
            "commons|c=i" => 'Supress LGs with common markers less than
                              threshold (default: disable)'
        }
    );
    my $number = $args->{options}->{number} // 0;
    my $length = $args->{options}->{length} // 0;
    my $interval = $args->{options}->{interval} // 0;
    my $commons = $args->{options}->{commons} // 0;

    $args = load_map_data($args);
    my @map_ids = get_map_ids $args;
    open my $config_fh, ">", "mergemap.maps_config" or die $!;
    for my $map_id (@map_ids){
        my $map_file = "mergemap-input-$map_id.map";
        open my $fh, ">", $map_file or die $!;
        print $config_fh "$map_id 1 $map_file\n";
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            my %markers_hash = get_markers_hash $args, $map_id, $LG;
            my @marker_ids = sort {$markers_hash{$a} <=> $markers_hash{$b}}
                              keys %markers_hash;
            my $max = max(values %markers_hash);
            my $min = min(values %markers_hash);
            my $LG_length = $max - $min;
            my $average_interval = @marker_ids > 1 ? 
                                  $LG_length / (@marker_ids - 1) : 0;
            my $common_markers;
            my @common_markers;
            for my $map_id2 (@map_ids){
                next if $map_id eq $map_id2;
                push @common_markers, get_common_marker_num 
                    $args, $map_id, $map_id2, $LG;
            }
            $common_markers = sum(@common_markers);

            next if $number > 0 and @marker_ids < $number 
                    or $length > 0 and $LG_length < $length
                    or $interval > 0 and $average_interval > $interval
                    or $commons > 0 and $common_markers < $commons;

            printf  "Common markers for %s LG %s: %s ".
                    "(min: %d, max: %d, sum: %d, valid: %d)\n",         
                    $map_id, $LG,
                    join(",", @common_markers),
                    min(@common_markers), max(@common_markers), 
                    sum(@common_markers), scalar(grep{$_ > 0}@common_markers);
            printf "Number of markers: %d; Length: %.1f; Interval: %.2f\n",
                scalar(@marker_ids), $LG_length, $average_interval;


            print $fh "group $LG\n";
            print $fh ";BEGINOFGROUP\n";
            for my $marker_name (@marker_ids){
                my $genetic_pos = 
                    $args->{map_data}->{$map_id}->{$LG}->{$marker_name};
                print $fh "$marker_name\t$genetic_pos\n";
            }
            print $fh ";ENDOFGROUP\n";
        }
        close $fh;
    }
    close $config_fh;
}

#
# Run MergeMap LG-by-LG
# 

sub mergemapLG{
    my $args = new_action(
        -desc => 'Prepare input data for mergemap LG-by-LG'
    );

    $args = load_map_data($args);
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

############################################################
# Common markers
############################################################

sub list_commons{
    my $args = new_action(
        -desc => 'List common markers'
    );
    
    $args = load_map_data $args;
    my @results;
    my %marker_indexed_map_data = get_marker_indexed_map_data $args;
    for my $marker (keys %marker_indexed_map_data){
        my @array = values %{$marker_indexed_map_data{$marker}};
        next if @array == 1;
        for(my $i = 0; $i < $#array; $i++){
            for(my $j = $i + 1; $j <= $#array; $j++){
                my ($map_id1, $LG1, $pos1) = @{$array[$i]};
                my ($map_id2, $LG2, $pos2) = @{$array[$j]};
                push @results, [$marker,  $map_id1, $LG1, $pos1, 
                                          $map_id2, $LG2, $pos2];
            }
        }
    }
    @results = sort {$a->[2] <=> $b->[2] or 
                    $a->[3] <=> $b->[3]
                    }@results;
    for my $result (@results){
        print join ("\t", @$result)."\n";
    }
    
}

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
    $args = load_map_data($args);

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
    $args = load_map_data($args);
    my @map_ids = get_map_ids($args);
    if ($LG_mode){
        # Print title
        print join("\t", "Map ID", "LG", "Number of markers", 
                        "Length", "Average marker interval", 
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
                print join("\t", $map_id, $LG, $num_markers, 
                    $length, $average_intervals, $LG_start, $LG_end)."\n";
            }
        }
    }
    else{
        # Print title
        print join("\t", "Map ID", "Number of LGs", 
            "Number of markers", "Total length", "Average marker interval").
            "\n" if $print_title;
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
            my $average_interval = sprintf "%.2f", 
                $length / ($num_markers - $num_LG);
            print join("\t", $map_id, $num_LG."_LGs", 
                $num_markers, $length, $average_interval
                )."\n";
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
            else{die "Color mode ERROR: $mode!!!"}
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
    die "CAUTION: -s is required!" unless $args->{options}->{scaffold};
    
    $args = load_map_data $args;
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

sub print_conf_file{
    my ($conf_file, $karyotype_file, $highlights_file, $segdup_file) = @_;
    my $figure_file = $conf_file;
    $figure_file =~ s/conf-/figure-/;
    $figure_file =~ s/.txt/.png/;
    open my $conf_fh, ">", $conf_file or die $!;
    print $conf_fh <<"end_of_conf_file";
    show_links      = no
    show_highlights = no
    show_text       = no
    show_heatmaps   = no
    show_scatter    = no
    show_histogram  = no
    karyotype = $karyotype_file
    chromosomes_order_by_karyotype = yes
    chromosomes_units              = 1000000
    chromosomes_display_default    = yes
<ideogram>
    show = yes
    show_bands = yes
    fill_bands = yes
    band_transparency = 4
    <spacing>
        default = 0.003r
    </spacing>
    radius           = 0.7r
    thickness        = 5p
    fill             = yes
    stroke_color     = dgrey
    stroke_thickness = 2p
    show_label       = yes
    label_font       = default
    label_radius     = 1.05r
    label_size       = 30
    label_parallel   = no
</ideogram>
<plots>
    label_font = light
    label_size =25p
    rpadding   = 10p
    <plot>
         type=highlight
            file = $highlights_file
        r0 = dims(ideogram,radius_inner) - 0.02r
        r1 = dims(ideogram,radius_inner) + 0.03r
        z    = 10
     </plot>
</plots>
<highlights>
    z = 0
</highlights>
<links>
    <link>
        file = $segdup_file
        color         = orange
        radius        = 0.95r
        bezier_radius = 0.1r
        thickness     = 1
    </link>
</links>
    show_ticks        = yes
    show_tick_labels  = yes
    show_grid         = yes
<ticks>
    tick_label_font  = light
    radius           = dims(ideogram,radius_outer) + 0.02r
    label_offset     = 5p
    label_size       = 16p
    multiplier       = 1e-6
    color            = black
    thickness        = 1p
    <tick>
        spacing        = 50u
        size           = 14p
        show_label     = yes
        format         = %d
        suffix         = cM
    </tick>
    #<tick>
    #    label_separation = 1p
    #    spacing          = 10u
    #    size             = 7p
    #    show_label       = no
    #    format           = %d
    #</tick>
</ticks>
<image>
<<include etc/image.conf>>
    file  = $figure_file
    png   = yes
    svg   = yes
</image>
<<include etc/colors_fonts_patterns.conf>>
<<include etc/housekeeping.conf>>    

end_of_conf_file
    close $conf_fh;
}

sub convert_LG_pos_to_range{
    my ($LG_hash, $LG_range, $map_id, $marker) = @_;
    my ($min, $max) = @{$LG_range->{$map_id}};
    my $LG_pos = $LG_hash->{$map_id}->{$marker} * 1_000_000;
    my ($start, $end) = ($LG_pos - 1000, $LG_pos + 1000);
    $start = $min if $LG_pos - 1000 < $min;
    $end   = $max if $LG_pos + 1000 > $max;
    return ($start, $end);
}

sub is_consensus_map{
    my $map_id = shift;
    if($map_id =~ /mergemap/i){
        return 1;
    }else{
        return 0;
    }
}

sub determine_color{
    my ($map_ids, $i, $j) = @_;
    my $color = 'grey';
    if(is_consensus_map($map_ids->[$i])){
        $color = "chr$j";
    }
    elsif(is_consensus_map($map_ids->[$j])){
        $color = "chr$i";
    }
    return $color;
}

sub print_segdup_data{
    my ($LG_hash, $LG_range, $map_ids, $segdup_fh) = @_;
    my %LG_hash = %$LG_hash;
    my %LG_range = %$LG_range;
    my @map_ids = @$map_ids;
    for (my $i = 0; $i < $#map_ids; $i++){
        for(my $j = $i + 1; $j <= $#map_ids; $j++){
            my $map_id1 = $map_ids[$i];
            my $map_id2 = $map_ids[$j];
            #next unless is_consensus_map($map_id1) or
            #            is_consensus_map($map_id2);
            my @markers = keys %{$LG_hash{$map_id1}};
            for my $marker (@markers){
                if(exists $LG_hash{$map_id2}->{$marker}){
                    my ($start1, $end1) = convert_LG_pos_to_range
                        $LG_hash, $LG_range, $map_id1, $marker;
                    my ($start2, $end2) = convert_LG_pos_to_range
                        $LG_hash, $LG_range, $map_id2, $marker;
                    my $color = determine_color \@map_ids, $i, $j;
                    printf $segdup_fh "%s %d %d %s %d %d %s\n",
                        $map_id1, $start1, $end1, 
                        $map_id2, $start2, $end2,
                        "color=$color";
                }
            }
        }
    }
}

sub karyotype{
    my $args = new_action(
        -desc => 'Prepare karyotype data for circos figures',
    );
    $args = load_map_data $args;
    my %karyotype = get_LG_indexed_map_data $args;
    for my $LG (sort {$a cmp $b} keys %karyotype){
        my $karyotype_file = qq/data-karyotype-pear-LG$LG.txt/;
        my $highlights_file = qq/data-highlights-pear-LG$LG.txt/;
        my $segdup_file = qq/data-segdup-pear-LG$LG.txt/;
        my $conf_file = qq/conf-pear-LG$LG.txt/;
        print_conf_file $conf_file, 
            $karyotype_file, 
            $highlights_file,
            $segdup_file;
        open my $karyotype_fh, ">", $karyotype_file or die $!;
        open my $highlights_fh, ">", $highlights_file or die $!;
        open my $segdup_fh, ">", $segdup_file or die $!;
        my %LG_hash;
        my %LG_range;
        my @map_ids = sort {$a cmp $b} keys %{$karyotype{$LG}};
        for (my $map_id_count = 0; $map_id_count < @map_ids; $map_id_count++){
            my $map_id = $map_ids[$map_id_count];
            my %markers_hash = get_markers_hash $args, $map_id, $LG;
            my $min = min(values %markers_hash) * 1_000_000;
            my $max = max(values %markers_hash) * 1_000_000;
            $LG_hash{$map_id} = \%markers_hash;
            # Karyotype format:
            # chr - ID LABEL START END COLOR
            $LG_range{$map_id} = [$min, $max];
            print $karyotype_fh 
                "chr - $map_id $map_id $min $max chr$map_id_count\n";
            my @sorted_markers_list = 
                sort {$markers_hash{$a} <=> $markers_hash{$b}} 
                keys %markers_hash;
            for my $marker (@sorted_markers_list){
                my $LG_pos = $markers_hash{$marker};
                my ($start, $end) = convert_LG_pos_to_range
                    \%LG_hash, \%LG_range, $map_id, $marker;
                printf $highlights_fh "%s %d %d\n",
                    $map_id, $start, $end;
            }
        }
        print_segdup_data \%LG_hash, \%LG_range, \@map_ids, $segdup_fh;
        close $karyotype_fh;
        close $highlights_fh;
        close $segdup_fh;
    }
}

sub conflicts{
    my $args = new_action(
        -desc => 'print conflicts',
        -options => {
            "invert_match|v" => 'Invert match'
        }
    );
    my $invert_match = $args->{options}->{invert_match};
    $args = load_map_data $args;
    my %conflicts;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs = get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            my @marker_names = get_marker_names $args, $map_id, $LG;
            for my $marker_name (@marker_names){
                my $genetic_pos = 
                    get_genetic_pos $args, $map_id, $LG, $marker_name;
                push @{$conflicts{$marker_name}}, [$map_id, $LG, $genetic_pos];
            }
            
        }
    }
    
    for my $marker_name (sort {$a cmp $b} keys %conflicts){
        my @info = @{$conflicts{$marker_name}};
        my %hash;
        for my $info (@info){
            my ($map_id, $LG, $genetic_pos) = @$info;
            $hash{$LG}++;
        }
        my $is_conflict = keys %hash > 1 ? 1 : 0;
        $is_conflict = !$is_conflict if $invert_match;
        if($is_conflict){
            for my $info (@info){
                my ($map_id, $LG, $genetic_pos) = @$info;
                print join ("\t", 
                    $map_id, $LG, $marker_name, $genetic_pos
                    )."\n";
            }
        }
    }
    
}

sub report{
    my $args = new_action(
        -desc => 'Report the consensus map. Main function is to map marker in
                  consensus map against the original map',
        -options => {
            "linear_map_chart|l=s" => 'File "linear_map_chart.txt"'
        }
    );

    my $linear_map_chart = $args->{options}->{linear_map_chart};
    die qq/File "linear_map_chart.txt" is required!\n/ 
        unless $linear_map_chart;
    $args = load_map_data $args;
    my @map_ids = get_map_ids $args;
    my %marker_info = get_marker_indexed_map_data $args;
    open my $fh, $linear_map_chart or die $!;
    my $group;
    while(<$fh>){
        next if /^\s*$/ or /^\s*;/;
        if (/^group\s+(\S+)/){
            $group = $1;
        }
        elsif(/^(\S+)\s+(-?\d+(\.\d+)?)/){
            my ($marker_info, $pos) = ($1, $2);
            die "CAUTION: Group number is unknown!" unless $group;
            my @markers = split /,/, $marker_info;
            for my $marker (@markers){
                print join("\t",
                          $linear_map_chart, 
                          $group,
                          $marker,
                          $pos,
                          map{
                              defined $marker_info{$marker}->{$_} ? 
                              join("|", @{$marker_info{$marker}->{$_}}) : "NA"
                          }@map_ids
                    )."\n";
            }
        }
        else{
            die "CAUTION: $_";
        }
    }
    close $fh;
}

############################################################
# Create bin markers          
############################################################

sub add_scf_prefix{
    my ($scaffold, $file) = @_;
    if($file =~ /Pbr/){
        $scaffold = "Pbr-$scaffold";
    }
    elsif($file =~ /Pco/){
        $scaffold = "Pco-$scaffold";
    }
    return $scaffold;
}

sub read_blastn_files{
    my ($args, @blastn_files) = @_;
    my %markers_in_map = get_marker_indexed_map_data $args;
    my @results;
    for my $blastn_file (@blastn_files){
        open my $blastn_fh, $blastn_file or die $!;
        while(<$blastn_fh>){
            @_ = split /\t/;
            die qq/CAUTION: BLASTN parameter -outfmt "6 std qlen slen 
                        qcovs qcovhsp"/ unless @_ == 16;
            my $marker = $_[0];
            my $scaffold = $_[1];
            my $start = $_[8];
            my $end = $_[9];
            my $qcovs = $_[14];
            next unless $qcovs >= 95;
            next unless exists $markers_in_map{$marker};
            push @results, [$marker, 
                            add_scf_prefix($scaffold, $blastn_file), 
                            $start, $end];
        }
        close $blastn_fh;
    }
    return @results;
}

sub read_bowtie_files{
    my ($args, @bowtie_files) = @_;
    my %markers_in_map = get_marker_indexed_map_data $args;
    my @results;
    for my $bowtie_file(@bowtie_files){
        open my $bowtie_fh, $bowtie_file or die $!;
        while(my $aln1 = <$bowtie_fh>){
            my ($id1, $strand1, $scf1, $pos1, $seq1) = split /\t/, $aln1;
            my $aln2 = <$bowtie_fh>;
            my ($id2, $strand2, $scf2, $pos2, $seq2) = split /\t/, $aln2;
            $id1 =~ s|/[12]$||;
            $id2 =~ s|/[12]$||;
            die "ERROR in:\n  $aln1  $aln2"unless $id1 eq $id2
                                            and $scf1 eq $scf2
                                            and $strand1 eq '+'
                                            and $strand2 eq '-';
            my $start = $pos1 + 1;
            my $end = $pos2 + length($seq2);
            next unless exists $markers_in_map{$id1};
            push @results, [$id1, add_scf_prefix($scf1, $bowtie_file),
                             $start, $end];
        }
        close $bowtie_fh;
    }
    return @results;
}

sub convert_aln{
    my $args = new_action(
        -desc => 'Convert blastn or bowtie data into a special data format,
              which consisted of 4 columns, MARKER SCAFFOLD START END',
        -options => {
            "blastn|n=s@" => 'blastn data, parameter for BLASTN: -evalue 1e-20 
                          -perc_identity 95 -outfmt "6 std qlen slen qcovs 
                          qcovhsp"',
            "bowtie|e=s@" => 'bowtie data, parameter for bowtie: -f -v 0 -I 0 
                          -X 500 -a'
        }
    );
    $args = load_map_data $args;
    my @results;
    my %markers_in_map = get_marker_indexed_map_data $args;
    my @blastn_files = get_option_array $args, 'blastn';
    my @bowtie_files = get_option_array $args, 'bowtie';
    push @results, read_blastn_files $args, @blastn_files;
    push @results, read_bowtie_files $args, @bowtie_files;
    @results = sort{$a->[1] cmp $b->[1]
                or  $a->[2] <=> $b->[2]
                }@results;
    print join("\t", @$_)."\n" for @results;
}

sub are_bin_markers{
    my ($array_ref, $i, $j, $window) = @_;
    my @positions;
    my %scaffolds;
    for ($i .. $j){
        my ($id, $scf, $start, $end) = @{$array_ref->[$_]};
        push @positions, $start, $end;
        $scaffolds{$scf}++;
    }
    my $min_pos = min(@positions);
    my $max_pos = max(@positions);
    return 0 if keys %scaffolds > 1;
    return 0 if ($max_pos - $min_pos + 1) > $window;
    return 1;
}

sub print_bin{
    my ($array_ref, $i, $j, $bin_count) = @_;
    my @positions;
    my %scaffolds;
    my %ids;
    for ($i .. $j){
        my ($id, $scf, $start, $end) = @{$array_ref->[$_]};
        push @positions, $start, $end;
        $scaffolds{$scf}++;
        $ids{$id}++;
    }
    my @ids = sort {$a cmp $b} keys %ids;
    my $min_pos = min(@positions);
    my $max_pos = max(@positions);
    my ($scaffold) = keys %scaffolds;
    printf "Bin%04d\t%s\t%d\t%d\t%d\t%s\n", 
        $bin_count,
        $scaffold, 
        $min_pos, 
        $max_pos, 
        scalar(@ids),
        join(",", @ids);
    return 1;
}

sub greedy{
    my $args = new_action(
        -desc => 'binmarkers 2.0, use results from action convert_aln as
                  input data',
        -options => {
            "window|w=i" => 'Window size, default: 10000'
        }
    );
    my $window = $args->{options}->{window} // 10_000;
    my @data;
    my @fhs = get_in_fhs $args;
    for my $fh (@fhs){
        while(<$fh>){
            chomp;
            push @data, [split /\t/];
        }
    }

    my $bin_count = 0;
    my %binmarkers;
    for(my $i = 0; $i <= $#data; $i++){
        my $j = $i + 1;
        while($j <= $#data){
            last unless are_bin_markers(\@data, $i, $j, $window);
            $j++;
        }
        $bin_count++;
        print_bin(\@data, $i, $j - 1, $bin_count);
        $i = $j - 1; 
    }
}

sub is_same_map_same_LG{
    my ($markers_data, @markers) = @_;
    my %check;
    for my $marker (@markers){
        for my $map_id (keys %{$markers_data->{$marker}}){
            my ($map_id, $LG, $genetic_pos) =     
                @{$markers_data->{$marker}->{$map_id}};
            $check{$map_id}->{$LG}++;
        }
    }
    my $count = 0;
    for my $key1 (keys %check){
        for my $key2 (keys %{$check{$key1}}){
            $count++;
        }
    }
    die if $count == 0;
    return $count > 1 ? 0 : 1;
}

sub annotate_binmarkers{
    my $args = new_action(
        -desc => 'annotate binmarkers',
        -options => {
            "binmarkers|b=s" => 'bin markers data created by action 
                                binmarkers2',
            "threshold|t=f" => 'If markers in a bin have genetic position 
                                difference larger than the threshold (cM), then 
                                remove this bin marker [default: 10].
                                Set as unlimited if threshold less than or 
                                equal to 0'
        }
    );
    
    $args = load_map_data $args;
    my %markers_data = get_marker_indexed_map_data $args;
    my $bin_markers_file = $args->{options}->{binmarkers};
    my $threshold = $args->{options}->{threshold} // 10;
    die "CAUTION: bin markers file is required with -b" 
        unless $bin_markers_file;
    open my $bin_markers_fh, $bin_markers_file or die $!;
    LABEL: while(<$bin_markers_fh>){
        chomp;
        my ($binmarker, $scaffold, $start, $end, $count, $marker_list)
            = split /\t/;
        next if $count == 1;
        my @markers = split /,/, $marker_list;
        
        # If all markers were in the same map, same LG, then omit this
        # bin marker
        next if is_same_map_same_LG \%markers_data, @markers;

        # If this bin marker should keep and there were multiple
        # markers in one LG, then choose average LG position as 
        # the position of this bin marker.

        my %bin_marker_info;
        for my $marker (@markers){
            for my $map_id (keys %{$markers_data{$marker}}){
                my ($map_id, $LG, $genetic_pos) = 
                    @{$markers_data{$marker}->{$map_id}};
                $bin_marker_info{$map_id}->{$LG}->{$marker} = $genetic_pos;
            }
        }

        for my $map_id (keys %bin_marker_info){
            for my $LG (keys %{$bin_marker_info{$map_id}}){
                my %hash = %{$bin_marker_info{$map_id}->{$LG}};
                my @positions = values %hash;
                my $bin_marker_pos = sprintf "%.1f",
                    sum(@positions) / scalar(@positions);
                next LABEL if $threshold > 0 and 
                              max(@positions) - min(@positions) > $threshold;
                print join("\t",  $map_id, $LG, 
                                $binmarker, $bin_marker_pos, 
                                join(",", sort {$a cmp $b} keys %hash),
                                join(",", map {$hash{$_}} sort {$a cmp $b} keys %hash)
                         )."\n";
            }
        }
    }
    close $bin_markers_fh;
}

sub remove_redundant{
    my $args = new_action(
        -desc => 'Remove redundant markers that are in the same location in 
                  a map'
    );
    $args = load_map_data $args;
    my @map_ids = get_map_ids $args;
    for my $map_id (@map_ids){
        my @LGs= get_LG_ids $args, $map_id;
        for my $LG (@LGs){
            my %hash = get_markers_hash $args, $map_id, $LG;
            my %tmp;
            for my $marker(keys %hash){
                push @{$tmp{$hash{$marker}}}, $marker;
            }
            for my $position (sort {$a <=> $b} keys %tmp){
                my @markers = @{$tmp{$position}};
                my @selected;
                map{push @selected, $_ if $markers[$_] =~ /^Bin/}(0..$#markers);
                if(@selected == 0){
                    push @selected, int(rand(scalar(@markers)));
                }
                for my $marker(@markers[@selected]){
                    print join("\t", $map_id, $LG, $marker, $hash{$marker}
                            )."\n";
                }
            }
        }
    }
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# This subroutine is used to prepare data for MareyMap 
# MareyMap is a R package to draw relationship between 
# genetic map and physical map
# Typical MareyMap input data format is: 
#   "set" "map" "mkr" "phys" "gen" "vld"
#   "Arabidopsis thaliana" "Chromosome 1" "SGCSNP131" 184351 0 TRUE
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

sub mareymap{
    our $args = new_action(
        -desc => 'Creating input data for MareyMap to draw draw dotplot 
                  for genetic map and physical map using MareyMap. ',
        -options => {
            "blastn|n=s@" => 'blastn data, parameter for BLASTN: -evalue 1e-20 
                          -perc_identity 95 -outfmt "6 std qlen slen qcovs 
                          qcovhsp"',
            "bwotie|e=s@" => 'bowtie data, parameter for bowtie: -f -v 0 -I 0 
                          -X 500 -a',
        }
    );
    
    my $species = 'Pyrus bretschneideri';
    

    $args = load_map_data $args;
    my @blastn_files = get_option_array $args, 'blastn';
    my @bowtie_files = get_option_array $args, 'bowtie';
    
    die "blastn or bowtie files was unassigned" 
        unless @blastn_files or @bowtie_files;
    
    my @results;
    push @results, read_blastn_files $args, @blastn_files;
    push @results, read_bowtie_files $args, @bowtie_files;
    @results = sort{$a->[1] cmp $b->[1] or
                    $a->[2] <=> $b->[2]
               }@results;
    my %markers_in_map = get_marker_indexed_map_data $args;
    for my $info (@results){
        my ($marker, $scaffold, $start, $end) = @$info;
        my @info = values %{$markers_in_map{$marker}};
        die if @info > 1;
        my ($map_id, $LG, $genetic_pos) = @{$info[0]};
        print join("\t", qq/"$species"/, qq/"$scaffold"/, qq/"$marker"/, 
                  int(($start + $end)/2), $genetic_pos, "TRUE"
              )."\n";
    }
}

__END__
