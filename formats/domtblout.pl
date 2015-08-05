#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use List::Util qw(max);
use lib "$FindBin::RealBin/../lib";
use Gfat::Cmd::Base qw(base_main get_fh);

sub actions{
    return {
        uniq  => [\&uniq_domains, "Print uniq domains from a domtblout file"],
        conserved => [\&conserved_domains, "Print all possible domains and align by first conserved domain(s)"]
    };
}

base_main(actions) unless caller;
exit;

#########################
# Defination of actions #
#########################


sub load_domtblout_file{
    my $fh = shift;
    my %data;
    while(<$fh>){
        next if /^\s*#/ or /^\s*$/;
        my @F            = split /\s+/;
        my $gene         = $F[0];
        my $query        = $F[3];
        my $evalue       = $F[6];
        my $bitscore     = $F[7];
        my $domain_index = $F[9];
        my $domain_num   = $F[10];
        my $c_evalue     = $F[11];
        my $i_evalue     = $F[12];
        my $hmm_from     = $F[15];
        my $hmm_to       = $F[16];
        my $ali_from     = $F[17];
        my $ali_to       = $F[18];
        my $env_from     = $F[19];
        my $env_to       = $F[20];
        push @{$data{$gene}},
            {gene     => $gene,
             query    => $query,
             evalue   => $evalue, 
             c_evalue => $c_evalue,
             ali_from => $ali_from,
             ali_to   => $ali_to};
    }
    return \%data;
}

sub is_overlap{
    my @domains = @_;
    my $to   = max(map{$domains[$_]->{ali_to}}(0 .. $#domains - 1));
    return $domains[-1]->{ali_from} <= $to ? 1 : 0;
}

sub best_domain{
    my @domains = @_;
    my $best_domain = $domains[0];
    my $lowest_evalue = 10;
    for my $domain (@domains){
        if($domain->{c_evalue} < $lowest_evalue){
            $best_domain = $domain;
            $lowest_evalue = $domain->{c_evalue};
        }
    }
    return $best_domain;
}

sub print_domain{
    my $domain = shift;
    my $gene     = $domain->{gene};
    my $query    = $domain->{query};
    my $evalue   = $domain->{c_evalue};
    my $ali_from = $domain->{ali_from};
    my $ali_to   = $domain->{ali_to};
    print "$gene\t$ali_from\t$ali_to\t$query\t$evalue\n";
}

sub get_uniq_domains {
    my $data = shift;
    my @uniq_domains;
    for my $gene (sort {$a cmp $b} keys %$data){
        my @domains = sort {$a->{ali_from} <=> 
                            $b->{ali_from}
                           }@{$data->{$gene}};
        for(my $i = 0; $i <= $#domains; $i++){
            my $begin = $i;
            for(my $j = $i + 1; $j <= $#domains; $j++){
                is_overlap(@domains[$begin..$j]) ?  $i++ : last;
            }
            my $end = $i;
            my $best = best_domain(@domains[$begin..$end]);
            push @uniq_domains, $best;
        }
    }
    return \@uniq_domains;
}

sub print_domains{
    my $domains = shift;
    map{print_domain($_)}@$domains;
}

sub print_genes{
    my $domains = shift;
    my %genes;
    map{push @{$genes{$_->{gene}}}, $_}@$domains;
    for my $gene (sort {$a cmp $b} keys %genes){
        my $pos = join(q/,/, map{$_->{ali_from}.q/-/.$_->{ali_to}}@{$genes{$gene}});
        my $dom_info = join(q/,/, map{$_->{query}}@{$genes{$gene}});
        print "$gene\t$pos\t$dom_info\n";
    }
}

sub uniq_domains{
    my ($in_fh, $out_fh, $options) = get_fh(q/uniq/, 
        "g|gene"  => 
        "            Print one gene per line [default: one domain per line]",
       );
    my $print_genes = $options->{gene};
    my $data = load_domtblout_file($in_fh);
    my $uniq_domains = get_uniq_domains($data);
    if($print_genes){print_genes($uniq_domains)}
    else{print_domains($uniq_domains)}
}

=head2 domtblout.pl conserved

  USAGE  : domtblout.pl conserved [OPTIONS]

  OPTIONS: -i,--input  FILE
           -o,--output FILE
           -h,--help
           -c,--conserved Domain[,Domain ...]

=cut

sub _get_conserved_pos{
    my ($domains, $conserved) = @_;
    my $i;
    for my $domain (@$domains){
        $i++;
        if($conserved->{$domain->{query}}){
            return $i;
        }
    }
    warn $domains->[0]->{gene},":NO conserved domain(s)!";
    return 1;
}

sub print_conserved_domains{
    my ($domains, @conserved_domains) = @_;
    my (%genes, %conserved);
    map{push @{$genes{$_->{gene}}}, $_}@$domains;
    map{$conserved{$_}++}@conserved_domains;

    # number of domains before or after conserved domain
    my ($before,$after) = (0, 0);
    for my $gene (keys %genes){
        my @domains = @{$genes{$gene}};
        my $conserved_pos = _get_conserved_pos(\@domains,\%conserved);
        $before = $conserved_pos if $conserved_pos > $before;
        $after  = scalar(@domains) - $conserved_pos 
            if (scalar(@domains) - $conserved_pos) > $after;
    }

    for my $gene (sort {$a cmp $b} keys %genes){
        my @domains = @{$genes{$gene}};
        my $conserved_pos = _get_conserved_pos(\@domains,\%conserved);
        my $out = "$gene" . "\t-" x ($before - $conserved_pos);
        for my $domain (@domains){
            my $domain_info = $domain->{query}.'['.
                $domain->{ali_from}.'-'.$domain->{ali_to}.']';
            $out .= "\t$domain_info";
        }
        $out .= "\t-" x ($after - (scalar(@domains) - $conserved_pos));
        print "$out\n";
    }

}

sub conserved_domains{
    my ($in_fh, $out_fh, $options) = get_fh(q/conserved/, 
        "c|conserved=s@" => "STR      conserved domains, could be multiple"
        );
    die "CAUTION: conserved domains should be specified!" 
        unless $options->{conserved};
    my @conserved_domains = split(/,/,join(',',@{$options->{conserved}}));

    my $data = load_domtblout_file($in_fh);
    my $uniq_domains = get_uniq_domains($data);
    print_conserved_domains($uniq_domains, @conserved_domains);
}


__END__
