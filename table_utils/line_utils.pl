#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use List::Util qw(sum max min);

sub base_usage{
    print <<USAGE;

perl $FindBin::Script CMD [OPTIONS]

  Dealing with plain file formats line by line.
  Convert line seperator among win, mac, and linux
  Count line length and maximum length

  win2linux| Replace \\r\\n to \\n
  win2mac  | Replace \\r\\n to \\r
  linux2win| Replace \\n to \\r\\n
  linux2mac| Replace \\n to \\r
  mac2win  | Replace \\r to \\r\\n
  mac2linux| Replace \\r to \\n

  length   | Print length of each line
  maxlen   | Max line length

  cc       | Character count
  vcc      | Visible character count
  ivcc     | Invisable character count

USAGE
    exit;
}

sub functions_hash{
    return (
        win2linux  => \&win2linux,
        win2max    => \&win2mac,
        linux2win  => \&linux2win,
        linux2mac  => \&linux2mac,
        mac2win    => \&mac2win,
        mac2linux  => \&mac2linux,
        length     => \&line_length,
        maxlen     => \&maxlen,
        cc         => \&char_count,
        vcc        => \&visible_char_count,
        ivcc       => \&invisible_char_count,
    );
}

sub base_main{
    base_usage unless @ARGV;
    my $cmd = shift @ARGV;
    my %functions = functions_hash;
    &{$functions{$cmd}} //  warn "Unrecognized command: $cmd!\n" and base_usage;
}

base_main() unless caller;

###################
# Define commands #
###################

#
# Common subroutines
#

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

sub get_options{
    my $cmd = shift;
    GetOptions(
        "input=s"  => \my $infile,
        "output=s" => \my $outfile,
        "help"     => \my $help
    );
    cmd_usage($cmd) if $help or (!$infile and @ARGV == 0 and -t STDIN);
    my ($in_fh, $out_fh) = (\*STDIN, \*STDOUT);
    $infile = shift @ARGV if (!$infile and @ARGV > 0);
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;

    return {
        in_fh => $in_fh,
        out_fh => $out_fh
    };
}

sub get_fh{
    my $cmd = shift;
    my $options = get_options($cmd);
    my $in_fh = $options->{in_fh};
    my $out_fh = $options->{out_fh};
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

#
# Command win2linux, win2mac, linux2win, linux2mac, mac2win, mac2linux
#

sub new_line_convert{
    my($from, $to) = @_;
    my %new_line = (win   => "\r\n",
                    linux => "\n",
                    mac   => "\r");
    my ($in_fh, $out_fh) = get_fh($from."2".$to);
    local $/ = $new_line{$from};
    local $\ = $new_line{$to};
    while(<$in_fh>){ print $out_fh $_ }
    close_fh($in_fh, $out_fh);
}

sub win2linux { new_line_convert(qw/win linux/) }
sub win2mac   { new_line_convert(qw/win mac/)   }
sub linux2win { new_line_convert(qw/linux win/) }
sub linux2mac { new_line_convert(qw/linux mac/) }
sub mac2win   { new_line_convert(qw/mac win/)   }
sub mac2linux { new_line_convert(qw/mac linux/) }

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

