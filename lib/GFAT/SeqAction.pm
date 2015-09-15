package GFAT::SeqAction;

use warnings;
use strict;
use GFAT::SeqActionBase;

sub acclist{
    my $action = new_action(
        -action      => 'acclist',
        -description => "Print ACC list for a sequence file",
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->accession_number, "\n";
    }
}

sub idlist{
    my $action = new_action(
        -action => 'idlist'
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->display_id, "\n";
    }
}

1;
