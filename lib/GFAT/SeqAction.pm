package GFAT::SeqAction;

use warnings;
use strict;
use GFAT::SeqActionNew;
use List::Util qw(sum max min);

sub acclist{
    my $action = new_seqaction(
        -description => "Print a list of accession numbers",
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->accession_number, "\n";
    }
}

sub ids{
    my $action = new_seqaction(
        -description => 'Print a list of sequence IDs',
        -options     => {
            "description|d" => 'Print a second column for descriptions',
            "until|u=s"     => 'Truncate the name and description at words'
        }
    );
    for my $in (@{$action->{in_ios}}){
        while( my $seq = $in->next_seq ){
            my $info = $seq->display_id . 
                ($action->{options}->{description} ? "\t".$seq->desc : '');
            my $re = $action->{options}->{until};
            $info =~ s/$re.*$// if defined $re;
            print "$info\n";
        }
    }
}

sub length{
    my $action = new_seqaction(
        -description => 'Print a list of sequence length',
        -options     => {
            "summary|s" => 'Print summary of sequence length'
        }
    );
    my @lengths;
    for my $in (@{$action->{in_ios}}){
        while( my $seq = $in->next_seq ){
            print $seq->display_id, "\t", $seq->length, "\n";
            push @lengths, $seq->length if $action->{options}->{summary};
        }
    }
    if($action->{options}->{summary}){
        die "CAUTION: No sequences!" unless @lengths;
        warn "Number of sequences: ", scalar(@lengths), "\n";
        warn "Total length: ", sum(@lengths), "\n";
        warn "Maximum length: ", max(@lengths), "\n";
        warn "Minimum length: ", min(@lengths), "\n";
        warn "Average length: ", sum(@lengths) / scalar(@lengths), "\n";
    }
}

1;
