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

sub acclist2{
    my $action = new(
        -action      => 'acclist2',
        -description => "Print ACC list for a sequence file",
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->accession_number, "\n";
    }
}

sub idlist2{
    my $action = new(
        -action => 'idlist2'
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->display_id, "\n";
    }
}

sub acclist_usage{
    print <<"usage";

USAGE 
    $FindBin::Script acclist [OPTIONS]

DESCRIPTION
    Print ACC list for a sequence file

OPTIONS
    -i,--infile FILE

usage
    exit;
}

sub acclist{
    acclist_usage unless @ARGV;
    my %options;
    GetOptions(\%options,
        "infile|i=s"
    );
    acclist_usage unless $options{infile};
    my $in_fh = GetInFh($options{infile});
    my $in = Bio::SeqIO->new(-fh => $in_fh,
                             -format => $::format);
    while( my $seq = $in->next_seq){
        print $seq->accession_number, "\n";
    }
}

sub idlist_usage{
    print <<"usage";

USAGE 
    $FindBin::Script idlist [OPTIONS]

DESCRIPTION
    Print ID list for a sequence file

OPTIONS
    -i,--infile FILE

usage
    exit;
}

sub idlist{
    idlist_usage unless @ARGV;
    my %options;
    GetOptions(\%options,
        "infile|i=s"
    );
    idlist_usage unless $options{infile};
    my $in_fh = GetInFh($options{infile});
    my $in = Bio::SeqIO->new(-fh => $in_fh,
                             -format => $::format);
    while( my $seq = $in->next_seq){
        print $seq->display_id, "\n";
    }
}

1;
