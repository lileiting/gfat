#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionBase qw(get_fh close_fh get_options base_main);
use List::Util qw(sum max min);

sub actions{
    return {
        linesep    => [ \&line_separator_convert, "Line separator convert (win/mac/linux)" ],
        length     => [ \&line_length,            "Print length of each line"              ],
        maxlen     => [ \&maxlen,                 "Max line length"                        ], 
        cc         => [ \&char_count,             "Character count"                        ], 
        vcc        => [ \&visible_char_count,     "Visible character count"                ], 
        ivcc       => [ \&invisible_char_count,   "Invisable character count"              ]
    };
}

base_main(actions) unless caller;

###################
# Define commands #
###################

#
# Line separator convert
#

sub line_separator_convert{
    my $options = get_options(qw/linesep/, 
                      "from=s" => "win/mac/linux/auto (Default: Auto)",
                      "to=s"   => "win/mac/linux (Default: Linux)"
                  );
    my ($in_fh, $out_fh, $from, $to) = @{$options}{qw/in_fh out_fh from to/};
    die "ERROR: from and to should all be defined\n" unless $from and $to;
    die "ERROR: $from! It should be win/mac/linux" 
        unless $from =~ /win|mac|linux/i;
    die "ERROR: $to! It should be win/mac/linux"
        unless $to =~ /win|mac|linux/i;
    my %line_sep = (win   => "\r\n",
                    linux => "\n",
                    mac   => "\r");
    local $/ = $line_sep{"\L$from\E"};
    local $\ = $line_sep{"\L$to\E"};
    while(<$in_fh>){ chomp; print $out_fh $_ }
    close_fh($in_fh, $out_fh);
}

# 
# Max line length
#

sub line_length{
    my ($in_fh, $out_fh) = get_fh(q/length/);
    while(<$in_fh>){
        chomp;
        print $out_fh length($_), "\n";
    }
    close_fh($in_fh, $out_fh);
}

sub maxlen{
    my ($in_fh, $out_fh) = get_fh(q/maxlen/);
    my $maxlen = 0;
    while(<$in_fh>){
        chomp;
        $maxlen = length($_) if length($_) > $maxlen;
    }
    print $out_fh $maxlen,"\n";
    close_fh($in_fh, $out_fh);
}

# 
# Character count
#

sub get_char_count{
    my $in_fh = shift;
    my %char;
    my $char = '';
    while(read($in_fh, $char, 1)){
        $char{ord($char)}++;
    }
    return %char;
}

sub is_visible_char   { return $_[0] >= 33 && $_[0] <= 126 ? 1 : 0 }
sub is_invisible_char { return $_[0] <  33 || $_[0] >  126 ? 1 : 0 }
sub decode{ return is_visible_char($_[0]) ? chr($_[0]) : "chr($_[0])"; }

sub char_count_main{
    my $cmd = shift;
    my ($in_fh, $out_fh) = get_fh($cmd);
    my %char = get_char_count($in_fh);

    for my $ord (sort {$a <=> $b} keys %char){
        my $count = $char{$ord};
        my $char = decode($ord);
        next if $cmd eq q/ivcc/ and is_visible_char($ord);
        next if $cmd eq q/vcc/  and is_invisible_char($ord);
        print $out_fh "$ord\t$char\t$count\n";
    }

    close_fh($in_fh, $out_fh);
}

sub char_count           { char_count_main(q/cc/)   }
sub visible_char_count   { char_count_main(q/vcc/)  }
sub invisible_char_count { char_count_main(q/ivcc/) }

