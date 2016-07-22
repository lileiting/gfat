#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw(max);
use Getopt::Long qw(:config gnu_getopt);

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]

ACTIONS
    uniq       | Print uniq domains from a domtblout file
    conserved  | Print all possible domains and align by first
                 conserved domain(s)

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}};
    }
    else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main() unless caller;

sub new_usage{
    my %args = @_;
    my $options_usage = '    '.join("\n    ",
        sort {$a cmp $b}keys %{$args{-options}});
    my $usage = "
USAGE
    $FindBin::Script $args{-action} infile [OPTIONS]
    $FindBin::Script $args{-action} [OPTIONS] infile

DESCRIPTION
    $args{-description}

OPTIONS
$options_usage

";
    return sub {print $usage; exit}
}

sub new{
    my %args = @_;
    my %action;
    die "Action name was not given!" unless $args{-action};
    $args{-description} //= $args{-action};
    $args{-options}->{"help|h"} //= "Print help";
    $args{-options}->{"out|o=s"}  //= "Output file";
    my $usage = new_usage(%args);
    my %options;
    GetOptions(\%options, keys %{$args{-options}});
    &{$usage} if $options{help} or (@ARGV == 0 and -t STDIN);
    my ($file, $fh) = (shift @ARGV, \*STDIN);
    if($file and $file ne '-' ){
        open $fh, "<", $file or die "$!";
    }
    $action{in_fh}=$fh;
    $action{options} = \%options;
    return \%action;
}


###########
# Actions #
###########

sub load_domtblout_file{
    my $fh = shift;
    my %data;
    while(<$fh>){
        next if /^\s*#/ or /^\s*$/;
        my @F            = split /\s+/;
        my $gene         = $F[0];
        my $query        = $F[3];
        my $qlen         = $F[5];  # Query length
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
        next unless $ali_to - $ali_from + 1 >= $qlen / 2;
        push @{$data{$gene}},
            {gene     => $gene,
             query    => $query,
             qlen     => $qlen,
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

sub uniq{
    my $action = new (
        -action => 'uniq',
        -description => 'Print uniq domains from a domtblout file',
        -options => {
            "gene|g" => 'Print one gene per line
                        [default: one domain per line]'
        }
    );

    my $print_genes = $action->{options}->{gene};
    my $data = load_domtblout_file($action->{in_fh});
    my $uniq_domains = get_uniq_domains($data);
    if($print_genes){print_genes($uniq_domains)}
    else{print_domains($uniq_domains)}

}

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

sub conserved{
    my $action = new(
        -action => 'conserved',
        -description => 'Print all possible domains and align by first
                        conserved domain(s)',
        -options => {
            "conserved|c=s@" => 'conserved domains, could be multiple'
        }
    );

    die "CAUTION: conserved domains should be specified!"
        unless $action->{options}->{conserved};
    my @conserved_domains = split(/,/, join(',',
                            @{$action->{options}->{conserved}}));

    my $data = load_domtblout_file($action->{in_fh});
    my $uniq_domains = get_uniq_domains($data);
    print_conserved_domains($uniq_domains, @conserved_domains);
}
