package GFAT::SeqAction;

use warnings;
use strict;
use FindBin;
use Getopt::Long;
use Bio::Perl;
use GFAT::Base qw(GetInFh);

sub generate_usage{
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
    $args{-format} //= $::format;
    $args{-options}->{"help|h"} //= "Print help";
    $args{-options}->{"out|o=s"}  //= "Output file";
    #$args{'-filenumber'} //= '1+'; # 1, 2, 3, 1+
    my $usage = generate_usage(%args);
    my %options;
    GetOptions(\%options, keys %{$args{-options}});
    &{$usage} if $options{help} or (@ARGV == 0 and -t STDIN);
    my $fh;
    if(@ARGV){
        my $file = shift @ARGV;
        if($file eq '-'){
            $fh = \*STDIN;
        }
        else{
            open $fh, "<", $file or die "$!";
        }
    }else{
        $fh = \*STDIN;
    }
    my $in = Bio::SeqIO->new(-fh => $fh, 
                             -format => $args{format});
    $action{in}=$in;
    return \%action;
}

sub acclist{
    my $action = new(
        -action      => 'acclist',
        -description => "Print ACC list for a sequence file",
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->accession_number, "\n";
    }
}

sub idlist{
    my $action = new(
        -action => 'idlist'
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->display_id, "\n";
    }
}

