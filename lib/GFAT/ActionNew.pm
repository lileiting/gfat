package GFAT::ActionNew;

use warnings;
use strict;
use FindBin;
use File::Basename;
use Getopt::Long qw(:config gnu_getopt);
use List::Util qw(max);
use Text::Wrap;
use Text::Abbrev;
use parent qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK);
@EXPORT = qw(new_action run_action);
@EXPORT_OK = @EXPORT;
our $dir = basename $FindBin::RealBin;
our $script = $FindBin::RealScript;
our $action;

sub new_action{
    my %args = @_;
    my %action;
    $args{-desc} = $args{-description} if exists $args{-description};
    die "Action descriptions were not given!" unless exists $args{-desc};
    $args{-options}->{"help|h"} //= "Print help";
    $args{-options}->{"outfile|o=s"}  //= "Output file name";

    my %options;
    GetOptions(\%options, keys %{$args{-options}});
    if($options{help} or (@ARGV == 0 and -t STDIN)){
        $args{-desc} =~ s/[\s\r\n]+/ /g;
        $args{-desc} = wrap("    ", "    ", $args{-desc});
        my $in_desc = $args{-in_desc} // $main::in_desc //
           '<infile|term> [<infile|term> ...]';
        print <<"end_of_usage";

USAGE
    gfat.pl $dir $script $action [OPTIONS] $in_desc

DESCRIPTION
$args{-desc}

OPTIONS
end_of_usage

        my @opt_keys = sort{$a cmp $b}(keys %{$args{-options}});
        my $max_opt_len = max(map{my $a = $_; $a =~ s/(=.+)$//; length($a) - 1 + 4
            }(@opt_keys)); #Prevent original strings be changed
        my %type = (i => 'INT',
                    s => 'STR',
                    f => 'FLT',  # Real number, eg. 3.14, -6.23E24
                    o => 'EXT'); # Extended integer, Perl style
        for my $option (@opt_keys){
            die "ERROR in option: $option"
                unless $option =~ /(\w+)\|(\w)(=([isfo])([%@]?))?/;
            my ($long, $short, $type0, $type, $multi) =
                ($1, $2, $3, $4, $5);
            my $opt_desc = $args{-options}->{$option};
            $opt_desc =~ s/[\s\r\n]+/ /g;
            $opt_desc = wrap(' ' x ($max_opt_len + 9),
                             ' ' x ($max_opt_len + 9), $opt_desc);
            $opt_desc =~ s/^\s+//;
            printf "    %-${max_opt_len}s %s %s\n",
                "-$short,--$long",
                $type0 ? $type{$type} : '   ',
                $opt_desc;
        }
        print "\n";
        exit;
    }

    if(@ARGV){
        for my $infile (@ARGV){
            my $in_fh;
            if($infile eq '-'){
                $in_fh = \*STDIN;
            }
            elsif(-e $infile){
                open $in_fh, "<", $infile or die "$!: $infile";
            }
            push @{$action{in_fhs}}, $in_fh if $in_fh;
            push @{$action{infiles}}, $infile if $infile ne '-';
        }
    }
    else{
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

sub run_action{
    my $script = $0;
    my %subroutines;
    open my $fh, $script or die "$!:$script";
    while(<$fh>){
        next unless /^sub\s+(\w+)/;
        my $subroutine = $1;
        next if $subroutine =~ /^main|^new|^_|usage$/;
        $subroutines{$subroutine} = 1;
    }
    close $fh;
    if(@main::ARGV){
        $action = shift @main::ARGV;
        die "WARNING: Invalid action name '$action!'\n"
            unless $action =~ /^\w+$/;
        my %actions = abbrev keys %subroutines;
        $action = $actions{$action}
            // die "CAUTION: action '$action' was not defined!\n";
        return $action;
    }
    else{
        my %actions = @_;
        map{die "CAUTION: No subroutine with the name: $_!\n"
                unless exists $subroutines{$_};
            $subroutines{$_} = 2} keys %actions;
        map{die "CAUTION: Description for '$_' was missing!\n"
                unless $subroutines{$_} == 2} keys %subroutines;
        print <<"end_of_usage";

USAGE
    gfat.pl $dir $script ACTION

ACTIONS
end_of_usage
        my $max_action_len = max(map{length}keys %actions);
        for my $action (sort {$a cmp $b} keys %actions){
            my $action_desc = $actions{$action};
            $action_desc =~ s/[\s\r\n]+/ /g;
            $action_desc = wrap(' ' x ($max_action_len + 7),
                                ' ' x ($max_action_len + 7), $action_desc);
            $action_desc =~ s/^\s+//;
            printf "    %${max_action_len}s | %s\n", $action, $action_desc;
        }
        print "\n";
        exit;
    }
}

1;
