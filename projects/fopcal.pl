#!/usr/bin/env perl

use warnings;
use strict;
use Bio::SeqIO;
use Getopt::Long;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::CodonTable;

############################################################
# Usage
############################################################

sub usage{
    print <<EOF;

USAGE
  fopcal.pl [OPTIONS]

OPTIONS
  -s,--sequence <GENOME.CDS.FASTA>
    sequence file

  -p,--optimal_codon_table <optimal_codon_table.txt>
    optimal codon table, two columns,
    first column is the 3-letter amino acid,
    second column is the optimal codon

  -c,--codon_table
    print codon table and exit

  -i,--inverse_table
    print inverse codon table and exit

  -e,--enc
    print effective number of codons (ENC, Nc)

  -m,--codon_matrix
    print a codon matrix for all genes

  -n,--num_of_codons
    print number of overall codons and exit

  -o,--optimal_codons
    print optimal codons and exit

  -h,--help
    print this usage

EOF
exit;
}

############################################################
# Read commands
############################################################

sub read_commands{
    usage unless @ARGV;
    my %para = (infile => '', out_fh => \*STDOUT);
    GetOptions(
        "s|sequence=s" => \$para{infile},
        "p|optimal_codon_table=s" => \$para{optimal_codon_table},
        "o|outfile=s" => \$para{outfile},
        "h|help" => \$para{help},
        "c|codon_table" => \$para{print_codon_table},
        "i|inverse_table" => \$para{print_inverse_table},
        "m|codon_matrix" => \$para{print_codon_matrix},
        "e|enc" => \$para{print_enc},
        "n|num_of_codons" => \$para{print_codon_number},
#        "o|optimal_codons" => \$para{print_optimal_codons}
    );

    if($para{outfile}){
        open my $fh, ">", $para{outfile} or die $!;
        $para{out_fh} = $fh;
    }

    if(exists $para{infile}){
        unless(-e $para{infile}){
            print STDERR "\nCAUTION: File $para{infile} not exist!\n";
            usage;
        }
    }elsif($para{codon_matrix} or
           $para{print_enc} or
           $para{print_codon_number} or
           $para{print_optimal_codons}){
            print STDERR "\nCAUTION: A sequence file is required!\n";
            usage;
    }
    return \%para;
}

############################################################
# Print codon matrix
############################################################

sub split2codons{
    my $seq = shift;
    my @codons;
    my @nt = split //, $seq;
    for(my $i = 1; $i <= int(scalar(@nt) / 3); $i++){
        push @codons, join('', @nt[($i-1)*3, ($i-1)*3 + 1, ($i-1)*3 + 2]);
    }
    return @codons;
}

sub print_codon_matrix{
    my $infile = shift;
    my %codon_table = get_codon_table;
    my @codon_table = sort{$a cmp $b}(keys %codon_table);

    print join(",", "SeqID", @codon_table),"\n";
    my $in_io = Bio::SeqIO->new(-file => $infile, -format=>'fasta');
    while(my $seqobj = $in_io->next_seq){
        my %codon_count;
        my $seqid = $seqobj->display_id;
        my $seqstr = $seqobj->seq;
        my @codons = split2codons($seqstr);
        for my $codon (@codons){
            $codon_count{$codon}++;
        }
        print join(",", $seqid,
                         map{
                             defined $codon_count{$_} ? $codon_count{$_} : 0
                         }@codon_table), "\n";
    }
    $in_io->close;

}

############################################################
# Calculate effective number of codons (ENC, Nc)
############################################################



sub cal_enc{
    my $seq = shift;
    my $is_effective_codon = shift;
    my @codons = split2codons($seq);
    my %enc;
    for my $codon (@codons){
        $enc{$codon}++ if $is_effective_codon->{$codon};
    }
    return scalar(keys %enc);
}

sub print_enc{
    my $infile = shift;

    my %codon_table = get_codon_table;
    my @effective_codons = grep{$codon_table{$_}->[0] ne '_'}
                           (keys %codon_table);
    my %is_effective_codon = map{$_ => 1}@effective_codons;
    my $in_io = Bio::SeqIO->new(-file => $infile, -format=>'fasta');
    while(my $seqobj = $in_io->next_seq){
        my $seqid = $seqobj->display_id;
        my $seqstr = $seqobj->seq;
        my $enc = cal_enc($seqstr, \%is_effective_codon);
        print "$seqid\t$enc\n";
    }
    $in_io->close;
    exit;
}

############################################################
# Count number of codons
############################################################

sub get_codon_number{
    my $infile = shift;
    my %codon_table = get_codon_table;
    my %codon_count;

    my $in_io = Bio::SeqIO->new(-file => $infile, -format=>'fasta');
    while(my $seqobj = $in_io->next_seq){
        my $seqstr = $seqobj->seq;
        my @codons = split2codons($seqstr);
        for my $codon (@codons){
            $codon_count{$codon}++;
        }
    }
    $in_io->close;

    map{$codon_count{$_} = 0 unless defined $codon_count{$_}}(keys %codon_table);
    return %codon_count;
}

sub resolve_codon_name{
    my $codon = shift;
    my %codon_table = get_codon_table;
    if($codon_table{$codon}){
        return $codon_table{$codon}->[1];
    }else{
        return "NA";
    }
}

sub print_codon_number{
    my $infile = shift;
    my %codon_number = get_codon_number($infile);
    my @sorted_codons =
           sort{resolve_codon_name($a) cmp resolve_codon_name($b)}
           (keys %codon_number);
    for my $codon (@sorted_codons){
        my $codon_name = resolve_codon_name($codon);
        printf "%s\t%s\t%s\n",
            $codon,
            $codon_name,
            $codon_number{$codon};
    }
    exit;
}

############################################################
# Get optimal codons
############################################################

sub get_optimal_codons{
    # Get optimal codons from a given sequence file
    # Input: a file name contains sequences with FASTA format
    # Output: a hash ref refer to optimal codons
    my $infile = shift;
    my %inverse_table = get_inverse_table;
    my %codon_count = get_codon_number($infile);
    my %optimal_codons;

    for my $aa (keys %inverse_table){
        my @codons = @{$inverse_table{$aa}}[2..$#{$inverse_table{$aa}}];
        $optimal_codons{$aa} =
           (sort{$codon_count{$b} <=>
            $codon_count{$a}}@codons)[0];
    }

    return %optimal_codons;
}

sub print_optimal_codons{
    my $infile = shift;
    my %optimal_codon = get_optimal_codons($infile);
    for my $codon (sort {$b cmp $a} keys %optimal_codon){
        print "$codon\t$optimal_codon{$codon}\n";
    }
    exit;
}

############################################################
# Calculate Fop
############################################################

sub calculate_fop{
    my ($infile, $optimal_codon, $out_fh) = @_;
    die unless -e $infile;
    my $in_io = Bio::SeqIO->new(-file => $infile, -format=>'fasta');
    while(my $seqobj = $in_io->next_seq){
        my $seqid = $seqobj->display_id;
        my $seqstr = $seqobj->seq;
        my @codons = split2codons($seqstr);
        my $num_of_codons = scalar(@codons);
        my $num_of_optimal = 0;
        my $num_of_non_optimal = 0;

        for my $codon (@codons){
             next unless $optimal_codon->{$codon};
             $num_of_optimal++ if $optimal_codon->{$codon} eq 'optimal';
             $num_of_non_optimal++ if $optimal_codon->{$codon} eq 'non-optimal';
        }

        my $fop = $num_of_optimal / ($num_of_optimal + $num_of_non_optimal);
        printf $out_fh "%s\t%d\t%d\t%d\t%f\n",
            $seqid,
            $num_of_codons,
            $num_of_optimal,
            $num_of_non_optimal,
            $fop;
    }
    $in_io->close;
    exit;
}

sub load_optimal_codon_table{
# Frequency of optimal codons was calculated by
# Number of optimal codons / sum of optimal and
# non-optimal codons

# The hash %optimal_codon store all 64 codons
# with three status, optimal, non-optimal,
# and ignore

    my $file = shift;
    my %optimal_codon;

    my %inverse_table = get_inverse_table;
    my %codon_family;
    for (keys %inverse_table){
        my $ref = $inverse_table{$_};
        $codon_family{$ref->[0]} = [@{$ref}[2..$#{$ref}]];
    }

    my %codon_table = get_codon_table;
    map{$optimal_codon{$_} = 'ignore'}(keys %codon_table);

    open my $fh, "<", $file or die "$file $!";
    my $num_of_aa;
    while(<$fh>){
        next if /^\s*#/ or /^\s*$/;
        $num_of_aa++;
        die "Optimal codon table error!" unless /(\w{3})\s+(\w{3,4})/;
        my ($aa, $codon) = ($1, $2);
        next if $codon !~ /[ATGC]{3}/;
        my @codon_family = @{$codon_family{$aa}};
        map{$optimal_codon{$_} = 'non-optimal'}@codon_family;
        $optimal_codon{$codon} = 'optimal';
    }
    close $fh;
    die "18 amino aci is expected!" unless $num_of_aa == 18;

    return \%optimal_codon;
}

sub print_hash_ref{
    my $ref = shift;
    my %codon_table = get_codon_table;
    for my $codon (keys %$ref){
        my $status = $ref->{$codon};
        my $aa = $codon_table{$codon}->[1];
        print STDERR "$aa\t$codon\t$status\n";
    }
}

############################################################
# Main
############################################################

sub main{
    my $para = read_commands;

    usage if $para->{help};
    print_codon_table if $para->{print_codon_table};
    print_inverse_table if $para->{print_inverse_table};
    print_codon_matrix($para->{infile}) if $para->{print_codon_matrix};
    print_enc($para->{infile}) if $para->{print_enc};
    print_codon_number($para->{infile}) if $para->{print_codon_number};
    print_optimal_codons($para->{infile}) if $para->{print_optimal_codons};

    #my $optimal_codon = load_optimal_codon_table($para->{optimal_codon_table});
    #print_hash_ref($optimal_codon);
    #calculate_fop($para->{infile}, $optimal_codon, $para->{out_fh});
}

main;
