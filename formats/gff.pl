#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    print <<"usage";

Usage
    $FindBin::Script ACTION [OPTIONS]

Availabe ACTIONs:
[ Statistics ]
    chrlist  | Print chromosome list
    genelist | Print gene list

[ subset ]
    groups   | Get a subset of GFF based on a two columns files
               (gene ID and their groups)

[ New data ]
    getintron| Get intron postions

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}};
    }else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main() unless caller;

###########
# Actions #
###########

#~~~~~~~~~~~~~gff data structure~~~~~~~~~~~~#

# Data structure
# HASH => GeneID => Type(gene, mRNA, CDS, exon, etc) 
#   => [type_entry1, type_entry2, etc] X 
#      [Chr, Start, End, Strand]
# $data{Pbr01.1}->{gene}->[0]->[0] = $chr
# $data{Pbr01.1}->{mRNA}->[0]->[0] = $chr
# $data{Pbr01.1}->{CDS}->[0]->[0] = $chr

sub _gff_entry{
    my $line = shift;
    my @F = split /\t/, $line;
    my ($chr, $type, $start, $end, $strand) = @F[0,2,3,4,6];
    my %info = grep{!/^\s*$/}(split /[;=]/, $F[8]);
    my $id = $info{ID} // $info{Parent} // die "Where is ID in \"$line\"";
    return (
        chr => $chr,
        type => $type,
        start => $start,
        end  => $end,
        strand => $strand,
        id => $id,
    )
}

sub _load_gff_file{
    #my $in_fh = shift;
    my %data; # %data => Gene ID => 
    print STDERR "Loading GFF file ...\n";
    for my $in_fh (@_){
        while(<$in_fh>){
            my %entry = _gff_entry($_);
            push @{$data{$entry{id}}->{$entry{type}}},
                 [$entry{chr},$entry{start}, $entry{end},$entry{strand}];
        }
    }
    return \%data;
}


#~~~~~~~~~~~~~~~~~~~~~chrlist~~~~~~~~~~~~~~~~#

sub _by_number{
    my $str = shift;
    my $num = 0;
    if($str =~ /^.+?(\d+)/){
        $num = $1;
    }
    return $num;
}

sub chrlist{
    my $args = new_action(
        -description => 'Print chromosome list'
    );
    my %chrs;
    my %types;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            my ($chr,undef, $type) = split /\t/;
            $chrs{$chr}->{$type}++;
            $types{$type}++;
        }
    }
    my @types = sort{$a cmp $b} keys %types;
    print join("\t", "Chr", @types),"\n";
    for my $chr (sort {_by_number($a) <=> _by_number($b)} keys %chrs){
        print join("\t", $chr, map{$chrs{$chr}->{$_} // 0}@types),"\n";
    }
}

#~~~~~~~~~~~~~~~~~~~genelist~~~~~~~~~~~~~~~~~~~~#


# What if intron exist inside UTR??????????
# What if intron exist between UTR and CDS
sub _number_of_exons{
    my ($data, $gene) = @_;
    return scalar(@{$data->{$gene}->{CDS}});
}

sub _number_of_introns{ return _number_of_exons(@_) - 1; }

sub genelist{
    my $args = new_action(
        -description => 'Print gene list'
    );
    my $data = _load_gff_file(@{$args->{in_fhs}});
    print "GeneID\tExons\tIntrons\n";
    for my $gene (sort {_by_number($a) <=> _by_number($b)} keys %$data){
        print "$gene",
              "\t", _number_of_exons($data,$gene),
              "\t", _number_of_introns($data,$gene),
              "\n";
    }
}

#~~~~~~~~~~~~~~~~~~~getintron~~~~~~~~~~~~~~~~~~~#

sub getintron{
    my $args = new_action(
        -description => 'Read a GFF and output a list of intron entries'
    );
    my %data; 
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            my ($chr, $type, $start, $end,$strand, $ann) = (split /\t/)[0,2,3,4,6,8];
            my ($id) = ($ann =~ /Parent=(.+?);/);
            next unless $type =~ /CDS|UTR/i;
            #print "$id\t$type\t$start\t$end\t$strand\n";
            $data{$id}->{$start}->{chr} = $chr;
            $data{$id}->{$start}->{type} = $type;
            $data{$id}->{$start}->{end} = $end;
            $data{$id}->{$start}->{strand} = $strand;
        }
    }
    for my $id (keys %data){
        my @starts = sort {$a <=> $b} keys %{$data{$id}};
        my $intron_count = 0;
        for (my $i = 1; $i <= $#starts; $i++){
            my $chr = $data{$id}->{$starts[$i]}->{chr};
            my $strand = $data{$id}->{$starts[$i]}->{strand};
            my $previous_end = $data{$id}->{$starts[$i-1]}->{end};
            my $present_start = $starts[$i];
            if($present_start - $previous_end > 1){
                $intron_count++;
                printf "%s\t%d\t%d\t%s\tID=%s_intron_%d;length=%d\n", $chr, 
                    $previous_end + 1, $present_start - 1, 
                    $strand, $id, $intron_count,
                    ($present_start - 1) - ($previous_end + 1) + 1;
            }
        }
    }
}

#~~~~~~~~~~~~~groups~~~~~~~~~~~#

sub _load_gene_list_file{
    my $file = shift;
    my %subfamilies;
    open my $fh, "<", $file or die;
    while(<$fh>){
        #print "Processing $_";
        chomp;
        @_ = split /\t/;
        $subfamilies{$_[0]} = $_[1];
    }
    close $fh;
    return \%subfamilies;
}

sub _create_fhs{
    my $subfamilies = shift;
    my %fhs;
    for my $subfamily (values %$subfamilies){
        next if $fhs{$subfamily};
        my $outfile = "subfamily-$subfamily.gff";
        warn "Creating file $outfile ...\n";
        open my $fh, ">", $outfile or die;
        $fhs{$subfamily} = $fh;
    }
    return \%fhs;
}

sub groups{
    my $args = new_action(
        -description => 'Get subset GFF information based on a two-column
                         file, and created multiple files based on the 
                         second column',
        -options     => { "listfile|l=s" => 'A two-column list file with 
                                            gene ID and the belonging groups'
                        }
    );
    die "CAUTION: List file is missing!\n" unless $args->{options}->{listfile};
    my $subfamilies = _load_gene_list_file($args->{options}->{listfile});
    my $fhs = _create_fhs($subfamilies);
    for my $fh (@{$args->{in_fhs}}){
        while(my $line = <$fh>){
            for my $gene (keys %$subfamilies){
                if($line =~ /$gene/){
                    $line =~ s/UTR_[53]/UTR/;
                    print {$fhs->{$subfamilies->{$gene}}} $line;
                    last;
                }
            }
        }
    }
}

__END__
