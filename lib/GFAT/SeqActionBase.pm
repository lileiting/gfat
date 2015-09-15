package GFAT::SeqActionBase;

use warnings;
use strict;
use FindBin;
use Getopt::Long qw(:config gnu_getopt);
use Bio::Perl;
use List::Util qw(max);
use parent qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK);
@EXPORT = qw(new_action);
@EXPORT_OK = qw(new_action);

sub resolve_options_usage{
    my %args = @_;

    my $options_usage = '';
    my @opt_keys = sort{$a cmp $b}(keys %{$args{-options}});
    my $max_opt_len = max(map{my $a = $_; $a =~ s/(=.+)$//;length($a)-1+4}(@opt_keys));

    my %type = (i => 'INT',
                s => 'STR',
                f => 'FLT',
                o => 'EXT');
    for my $option (@opt_keys){
        die "ERROR in option: $option"
            unless $option =~ /(\w+)\|(\w)(=([isfo])([%@]?))?/;
        my $desc = $args{-options}->{$option};
        my ($long, $short, $type0, $type, $multi) = ($1, $2, $3, $4, $5);

        my $string = sprintf "    %-${max_opt_len}s %s %s\n",
            "-$short,--$long",
            $type0 ? $type{$type} : '   ',
            $desc;

        $options_usage .= $string;
    }
    $options_usage =~ s/^\s+//;
    return $options_usage;
}


sub action_usage{
    my %args = @_;
    my $options_usage = resolve_options_usage(@_);
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
    $args{-informat} //= $::format;
    $args{-outformat} //= $::format;
    $args{-options}->{"help|h"} //= "Print help";
    $args{-options}->{"outfile|o=s"}  //= "Output file name";
    #$args{'-filenumber'} //= '1+'; # 1, 2, 3, 1+

    my $usage = action_usage(%args);
    my %options;
    GetOptions(\%options, keys %{$args{-options}});
    &{$usage} if $options{help} or (@ARGV == 0 and -t STDIN);

    my ($infile, $in_fh) = (shift @ARGV, \*STDIN);
    if($infile and $infile ne '-' ){
        open $in_fh, "<", $infile or die "$!";
    }
    my $in = Bio::SeqIO->new(-fh => $in_fh, 
                             -format => $args{-informat});

    my ($outfile, $out_fh) = ($options{outfile}, \*STDOUT);
    if($options{outfile} and $options{outfile} ne '-'){
        open $out_fh, ">", $outfile or die "$!";
    }

    my $out = Bio::SeqIO->new(-fh => $out_fh,
                           -format => $args{-outformat});

    $action{in} = $in;
    $action{out} = $out;
    $action{options} = \%options;
    return \%action;
}

1;
