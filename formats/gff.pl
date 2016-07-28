#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use List::Util qw(max);

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

sub genedensity{
    my $args = new_action(
        -desc => 'Print a statistics of gene density from GFF file',
        -options => {
            "window|w=i" => 'Window size [default: 1_000_000]',
            "type|t=s" => 'Entry type [default: mRNA]'
        }
    );
    my $window = $args->{options}->{window} // 1_000_000;
    my $check_type = $args->{options}->{type} // 'mRNA';
    my %statistics;
    for my $fh (@{$args->{in_fhs}}){
        while (<$fh>) {
            next if /^\s*$/ or /^\s*#/;
            chomp;
            my @F = split /\t/;
            my ($chr, $type, $start, $end) = @F[0,2,3,4];
            next unless $type eq $check_type;
            my $middle = sprintf "%f", ($start + $end) / 2;
            my $n = int($middle / $window) + 1;
            $statistics{$chr}->{$n}++;
        }
    }
    for my $chr (keys %statistics){
        my $max = keys %{$statistics{$chr}};
        for my $n (1..$max){
            print join("\t", $chr, $n * $window / 1_000_000,
                $statistics{$chr}->{$n} // 0)."\n";
        }
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
            next if /^\s*$/ or /^\s*#/;
            chomp;
            my ($chr, $type, $start, $end,$strand, $ann) = (split /\t/)[0,2,3,4,6,8];
            my ($id) = ($ann =~ /Parent=(.+?)/);
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
                printf "%s\t%d\t%d\t%s\tID=%s_intron_%d;Parent=%s;length=%d\n", $chr,
                    $previous_end + 1, $present_start - 1,
                    $strand, $id, $intron_count,$id,
                    ($present_start - 1) - ($previous_end + 1) + 1;
            }
        }
    }
}

#~~~~~~~~~~~~~getseq~~~~~~~~~~~#

sub _get_seqid_from_ann{
    my $ann = shift;
    my @ann = grep {!/^\s*$/} (split /;/,$ann);
    my %hash;
    map{@_ = split /=/;$hash{$_[0]} = $_[1]}@ann;
    die "ERROR: No seq ID! ... $ann\n" unless $hash{ID};
    return $hash{ID};
}

sub getseq{
    my $args = new_action(
        -desc => 'Get sequences',
        -options => {
            "db|d=s"   => 'Fasta sequence used to get sequences',
            "type|t=s" => 'Specify which feature type was used to get
                           sequences'
                    }
    );
    my $seqdb = $args->{options}->{db};
    die "A fasta sequence is required!\n" unless $seqdb;
    my $seqtype = $args->{options}->{type} // 'mRNA';
    use Bio::DB::Fasta;
    my $db = Bio::DB::Fasta->new($seqdb);
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            my ($chr,$type, $start, $end,$strand,$ann) =
                (split /\t/)[0,2,3,4,6,8];
            next unless $type eq $seqtype;
            my $seqid = _get_seqid_from_ann($ann);
            my $seqstr = $strand eq '+' ?
                $db->seq($chr, $start, $end) :
                $db->seq($chr, $end, $start);
            die "CAUTION: unable to obtain sequence for $seqid from $seqdb\n"
                unless $seqstr;
            $seqstr =~ s/(.{60})/$1\n/g;
            chomp $seqstr;
            print ">$seqid $chr|$start-$end|$strand|",$end - $start + 1,
                  "bp|$type\n$seqstr\n";
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

sub gff2info{
    my $args = new_action(
        -desc => 'Convert gff to a gene information as
Gene_ID\tChromosome\tLength_of_gene\tNo_of_exons\tAvg_exons\tAvg_introns',
    );

    my %gene_list;
    my $gff_file = shift @ARGV;

    print STDERR "Loading GFF file ...\n";
    my %info;
    for my $gff_fh (@{$args->{in_fhs}}){
        while(my $stream = <$gff_fh>){
            chomp($stream);
            my @txt = split /\t/,$stream;
            my @ann = split /;/,$txt[8];
            my %ann;
            map{@_ = split /=/,$_; $ann{$_[0]} = $_[1]}@ann;

            delete $ann{'ID'} if $txt[2] eq 'CDS';
            $gene_list{$ann{'ID'}}++ if $txt[2] eq 'mRNA';

            if($ann{'ID'}){ # mRNA
                $info{$ann{'ID'}}->{'chr'} = $txt[0];
                $info{$ann{'ID'}}->{'typ'} = $txt[2];
                $info{$ann{'ID'}}->{'sta'} = $txt[3];
                $info{$ann{'ID'}}->{'end'} = $txt[4];
                $info{$ann{'ID'}}->{'str'} = $txt[6];
            }elsif($ann{'Parent'}){ # UTR or CDS
                $info{$ann{'Parent'}}->{'count'}->{$txt[2]}++; # No. of CDSs

                $info{$ann{'Parent'}}->{$txt[2]}->{
                    $info{$ann{'Parent'}}->{'count'}->{$txt[2]}
                    }->{'sta'} = $txt[3]; # CDS -> start
                $info{$ann{'Parent'}}->{$txt[2]}->{
                            $info{$ann{'Parent'}}->{'count'}->{$txt[2]}
                            }->{'end'} = $txt[4]; # CDS -> end
                $info{$ann{'Parent'}}->{$txt[2]}->{
                            $info{$ann{'Parent'}}->{'count'}->{$txt[2]}
                            }->{'pha'} = $txt[7]; # CDS -> phase
            }else{die}
        }
    }


    my @lst = (keys %gene_list);

    print STDERR "Output gene information ...\n";
    print "#----------------------------------------------------------------------
#Gene_ID\tChromosome\tLength_of_gene\tNo_of_exons\tAvg_exons\tAvg_introns
#-----------------------------------------------------------------------
";
    for my $id (sort {$a cmp $b} @lst){
        my $len_exons;
        my %hash;

        for my $element (qw/CDS UTR_5 UTR_3/){
            if($info{$id}->{$element}){
                $hash{$element} = [keys %{$info{$id}->{$element}}];
            }
        }

        my $no_of_exons = $info{$id}->{'count'}->{'CDS'};
        die "ID: $id\n" unless $no_of_exons;

        my @border;
        for my $element (keys %hash){
            for my $i (@{$hash{$element}}){

                $len_exons += $info{$id}->{$element}->{$i}->{'end'}
                        - $info{$id}->{$element}->{$i}->{'sta'} + 1;
                push @border,
                    $info{$id}->{$element}->{$i}->{'end'},
                    $info{$id}->{$element}->{$i}->{'sta'};
            }
        }
        my $avg_exon = $len_exons / $no_of_exons;

        my($mRNA_start,$mRNA_end) = (sort {$a <=> $b} @border)[0,-1];
        my $avg_intron;
        if($no_of_exons > 1){
            $avg_intron = ($mRNA_end - $mRNA_start + 1 - $len_exons) /
                ($no_of_exons - 1) ; # No. of introns
        }else{
            $avg_intron = 0;
        }

        printf "%s\t%s\t%d\t%d\t%.1f\t%.1f\n",
            $id,
            $info{$id}->{'chr'},
            $info{$id}->{'end'} - $info{$id}->{'sta'} + 1,
            $no_of_exons, # No. of CDSs
            $avg_exon,
            $avg_intron;
    }
}

sub main{
    my %actions = (
        chrlist  => 'Print chromosome list',
        genedensity => 'Print gene density statistics',
        genelist => 'Print gene list (exon/intron number might not be
                   accurate for situations that intron located in UTRs)',
        getintron=> 'Get intron postions',
        getseq   => 'Get sequences',
        gff2info => 'Convert gff to a gene information as Gene_ID Chromosome
                    Length_of_gene No_of_exons Avg_exons Avg_introns',
        groups   => 'Get a subset of GFF based on a two columns files
                   (gene ID and their groups)',
    );
    &{\&{run_action(%actions)}};

}

our $in_desc = '<GFF> [<GFF> ...]';
main() unless caller;

__END__
