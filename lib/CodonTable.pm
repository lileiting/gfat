package CodonTable;
use warnings;
use strict;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(get_inverse_table get_codon_table 
             print_inverse_table print_codon_table);
@EXPORT_OK = @EXPORT;

############################################################
# Codon table defination
############################################################

sub get_inverse_table{
    return (
        A => [qw/Ala Alanine        GCT GCC GCA GCG        /],
        R => [qw/Arg Arginine       CGT CGC CGA CGG AGA AGG/],
        N => [qw/Asn Asparagine     AAT AAC                /],
        D => [qw/Asp Aspartic_acid  GAT GAC                /],
        C => [qw/Cys Cysteine       TGT TGC                /],
        Q => [qw/Gln Glutamine      CAA CAG                /],
        E => [qw/Glu Glutamine_acid GAA GAG                /],
        G => [qw/Gly Glycine        GGT GGC GGA GGG        /],
        H => [qw/His Histidine      CAT CAC                /],
        I => [qw/Ile Isoleucine     ATT ATC ATA            /],
        L => [qw/Leu Leucine        TTA TTG CTT CTC CTA CTG/],
        K => [qw/Lys Lysine         AAA AAG                /],
        M => [qw/Met Methionine     ATG                    /],
        F => [qw/Phe Phenylalanine  TTT TTC                /],
        P => [qw/Pro Proline        CCT CCC CCA CCG        /],
        S => [qw/Ser Serine         TCT TCC TCA TCG AGT AGC/],
        T => [qw/Thr Threonine      ACT ACC ACA ACG        /],
        W => [qw/Trp Tryptophan     TGG                    /],
        Y => [qw/Tyr Tyrosine       TAT TAC                /],
        V => [qw/Val Valine         GTT GTC GTA GTG        /],
        _ => [qw/Stp Stop_codon     TAA TGA TAG            /]
    );
}

sub get_codon_table{
    my %inverse_table = get_inverse_table;
    my %codon_table;

    for my $aa (keys %inverse_table){
        my @codons = @{$inverse_table{$aa}}[2..$#{$inverse_table{$aa}}];
        for my $codon (@codons){
            $codon_table{$codon} = [$aa, @{$inverse_table{$aa}}[0,1]];
        }
    }
    return %codon_table;
}

sub print_inverse_table{
    my %inverse_table = get_inverse_table;
    for my $aa (sort {$inverse_table{$a}->[0] cmp $inverse_table{$b}->[0]} 
                keys %inverse_table){
        my @info = @{$inverse_table{$aa}};
        printf "%s\t%s\t%-14s\t%s\n",
            $aa, @info[0,1],join(", ", @info[2..$#info]);
    }
    exit;
}

sub print_codon_table{
    my %codon_table = get_codon_table;
    for my $codon (sort {$a cmp $b} keys %codon_table){
        print "$codon\t",join("\t", @{$codon_table{$codon}}),"\n";
    }
    exit;
}

1;
