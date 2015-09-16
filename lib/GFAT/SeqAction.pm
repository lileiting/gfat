package GFAT::SeqAction;

use warnings;
use strict;
use GFAT::SeqActionNew;

sub acclist{
    my $action = new_action(
        -action      => 'acclist',
        -description => "Print ACC list for a sequence file",
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->accession_number, "\n";
    }
}

sub ids{
    my $action = new_action(
        -action => 'ids',
        -description => 'Print the FASTA sequence headers',
        -options => {
            "description|d" => 'Print a second column for descriptions',
        }
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->display_id, 
            $action->{options}->{description} ? "\t".$seq->desc : '', 
            "\n";
    }
}

1;
