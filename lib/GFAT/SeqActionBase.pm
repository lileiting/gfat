package GFAT::SeqActionBase;

use warnings;
use strict;
use FindBin;
use Getopt::Long qw(:config gnu_getopt);
use Bio::Perl;
use parent qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK);
@EXPORT = qw(new_action);
@EXPORT_OK = qw(new_action);

sub action_usage{
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

sub new_action{
    my %args = @_;
    my %action;
    die "Action name was not given!" unless $args{-action};
    $args{-description} //= $args{-action};
    $args{-format} //= $::format;
    $args{-options}->{"help|h"} //= "Print help";
    $args{-options}->{"out|o=s"}  //= "Output file";
    #$args{'-filenumber'} //= '1+'; # 1, 2, 3, 1+
    my $usage = action_usage(%args);
    my %options;
    GetOptions(\%options, keys %{$args{-options}});
    &{$usage} if $options{help} or (@ARGV == 0 and -t STDIN);
    my ($file, $fh) = (shift @ARGV, \*STDIN);
    if($file and $file ne '-' ){
        open $fh, "<", $file or die "$!";
    }
    my $in = Bio::SeqIO->new(-fh => $fh, 
                             -format => $args{format});
    $action{in}=$in;
    return \%action;
}

1;
