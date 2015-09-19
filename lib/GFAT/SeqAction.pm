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
            "until|u=s"       => 'Truncate the name and description at words'
        }
    );
    for my $in (@{$action->{in_ios}}){
        while( my $seq = $in->next_seq ){
            my $info = $seq->display_id . 
                ($action->{options}->{description} ? "\t".$seq->desc : '');
        
            my $re = $action->{options}->{until};
            if(defined $re){
                $info =~ s/$re.*$//;
            }
            print "$info\n";
        }
    }
}

1;
