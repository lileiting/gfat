package GFAT::SeqActionNew;

use warnings;
use strict;
use Bio::Perl;
use GFAT::ActionNew;
use parent qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK);
@EXPORT = qw(new_seqaction);
@EXPORT_OK = qw(new_seqaction);

sub new_seqaction{
    my %args = @_;
    my $action = new_action(%args);
    $args{-informat} //= $::format;
    $args{-outformat} //= $::format;
    for my $fh(@{$action->{in_fhs}}){
        my $in = Bio::SeqIO->new(-fh => $fh, 
                                 -format => $args{-informat});
        push @{$action->{in_ios}}, $in;
    }
    my $out = Bio::SeqIO->new(-fh => $action->{out_fh},
                           -format => $args{-outformat});
    $action->{out_io} = $out;
    return $action;
}

1;
