package Formats::Cmd::Base;
use warnings;
use strict;
use FindBin;
use Getopt::Long;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(get_fh close_fh);
@EXPORT_OK = @EXPORT;

sub cmd_usage{
    my $cmd = shift;
    print <<USAGE;

perl $FindBin::Script $cmd [OPTIONS]

 [-i,--input]  FILE
 -o,--output   FILE
 -h,--help

USAGE
    exit;
}

sub get_opt{
    my $cmd = shift;
    my %opt;
    GetOptions(
        "input=s"  => \$opt{infile},
        "output=s" => \$opt{outfile},
        "help"     => \$opt{help}
    );
    cmd_usage($cmd) if $opt{help} or (!$opt{infile} and @ARGV == 0 and -t STDIN);
    ($opt{in_fh}, $opt{out_fh}) = (\*STDIN, \*STDOUT);
    $opt{infile} = shift @ARGV if (!$opt{infile} and @ARGV > 0);
    open $opt{in_fh}, "<", $opt{infile} or die "$opt{infile}: $!" if $opt{infile};
    open $opt{out_fh}, ">", $opt{outfile} or die "$opt{outfile}: $!" if $opt{outfile};

    return \%opt;
}

sub get_fh{
    my $cmd = shift;
    my $opt = get_opt($cmd);
    my $in_fh = $opt->{in_fh};
    my $out_fh = $opt->{out_fh};
    return ($in_fh, $out_fh);
}

sub close_fh{
    my @fhs = @_;
    for my $fh (@fhs){
        close $fh unless 
               $fh eq \*STDIN  or 
               $fh eq \*STDOUT or 
               $fh eq \*STDERR;
    }
}

1;
