package Formats::Cmd::Base;
use warnings;
use strict;
use FindBin;
use Getopt::Long qw(:config no_ignore_case);
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(get_fh close_fh get_options);

sub key_in_opt{
    my $opt_name = shift;
    die "Option name ERROR: $opt_name!!!\n"
        unless $opt_name =~ /^(([A-Za-z])\|)?([a-z]+)(=[ifs])?$/;
    return ($3, $2);
}

sub cmd_usage{
    my ($cmd, @options) = @_;
    my @add_options = ();
    for(my $i = 0; $i < @options; $i+= 2){
        my ($opt, $desc) = @options[$i, $i+1];
        my ($long_option, $short_option) = key_in_opt($opt);
        $short_option = "-$short_option," if $short_option;
        $long_option  = "--$long_option";
        push @add_options, "    $short_option$long_option        $desc\n";
    }

    print <<USAGE;

  $FindBin::Script $cmd [OPTIONS]

    [-i,--input]  FILE
    -o,--output   FILE
    -h,--help
@add_options

USAGE
    exit;
}

sub get_options{
    my ($cmd, @opt) = @_;
    my %opt;
    die "@opt" unless @opt % 2 == 0;
    my @add_options;
    for(my $i = 0; $i < @opt; $i+= 2){
        my ($opt, $desc) = @opt[$i, $i+1];
        my ($opt_name) = key_in_opt($opt);
        push @add_options, $opt, \$opt{$opt_name};
    }
    GetOptions(
        "i|input=s"  => \$opt{infile},
        "o|output=s" => \$opt{outfile},
        "h|help"     => \$opt{help},
        @add_options
    );
    cmd_usage(@_) if $opt{help} or (!$opt{infile} and @ARGV == 0 and -t STDIN);
    ($opt{in_fh}, $opt{out_fh}) = (\*STDIN, \*STDOUT);
    $opt{infile} = shift @ARGV if (!$opt{infile} and @ARGV > 0);
    open $opt{in_fh}, "<", $opt{infile} or die "$opt{infile}: $!" if $opt{infile};
    open $opt{out_fh}, ">", $opt{outfile} or die "$opt{outfile}: $!" if $opt{outfile};

    return \%opt;
}

sub get_fh{
    my $cmd = shift;
    my $options = get_options($cmd);
    my ($in_fh, $out_fh) = @{$options}{qw/in_fh out_fh/};
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
