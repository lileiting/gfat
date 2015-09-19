package GFAT::ActionNew;

use warnings;
use strict;
use FindBin;
use Getopt::Long qw(:config gnu_getopt);
use List::Util qw(max);
use parent qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK);
@EXPORT = qw(new_action);
@EXPORT_OK = @EXPORT;

sub resolve_options_usage{
    my %args = @_;

    my $options_usage = '';
    my @opt_keys = sort{$a cmp $b}(keys %{$args{-options}});
    my $max_opt_len = max( map{ my $a = $_; 
                                $a =~ s/(=.+)$//;
                                length($a)-1+4
                              } (@opt_keys) );
    my %type = (i => 'INT',
                s => 'STR',
                f => 'FLT',
                o => 'EXT');
    for my $option (@opt_keys){
        die "ERROR in option: $option"
            unless $option =~ /(\w+)\|(\w)(=([isfo])([%@]?))?/;
        my $desc = $args{-options}->{$option};
        my ($long, $short, $type0, $type, $multi) = 
            ($1, $2, $3, $4, $5);
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
    my $file_info = $args{-filenumber} == 1 ? 'infile(s)' : 'file1 file2';
    my $usage = "
USAGE
    $FindBin::Script $args{-name} $file_info [OPTIONS]
    $FindBin::Script $args{-name} [OPTIONS] $file_info

DESCRIPTION
    $args{-description}

OPTIONS
    $options_usage
";
    return sub {print $usage; exit}
}

sub get_action_name{
    for my $level (1..3){
        my $subroutine = (caller($level))[3];
        if($subroutine =~ /new_action|new_seqaction/){
            next;
        }
        else{
            $subroutine =~ s/^.+:(.+)$/$1/;
            return $subroutine;
        }
    }
    die "CAUTION: Could not find action name!";
}

sub new_action{
    my %args = @_;
    my %action;
    die "Action description were not given!"
        unless $args{-description};
    $args{-name} //= get_action_name;
    $args{-options}->{"help|h"} //= "Print help";
    $args{-options}->{"outfile|o=s"}  //= "Output file name";
    $args{-filenumber} //= 1;

    my $usage = action_usage(%args);
    my %options;
    GetOptions(\%options, keys %{$args{-options}});
    &{$usage} if $options{help} or (@ARGV == 0 and -t STDIN);

    if(@ARGV){
        for my $infile (@ARGV){
            my $in_fh;
            if($infile ne '-'){
                open $in_fh, "<", $infile or die "$!";
            }
            else{
                $in_fh = \*STDIN;
            }
            push @{$action{in_fhs}}, $in_fh;
        }
    }else{
        my $in_fh = \*STDIN;
        push @{$action{in_fhs}}, $in_fh;
    }

    my ($outfile, $out_fh) = ($options{outfile}, \*STDOUT);
    if($options{outfile} and $options{outfile} ne '-'){
        open $out_fh, ">", $outfile or die "$!";
    }
    $action{out_fh} = $out_fh;
    $action{options} = \%options;
    return \%action;
}

1;
