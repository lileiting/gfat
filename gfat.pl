#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use File::Find;
use File::Basename;

############################################################
#                       MAIN USAGE                         #
############################################################

sub main_usage{
    print <<"end_of_usage";

NAME
    $FindBin::Script - Gene Family Analysis Tools

AVAILABLE CATEGORIES
end_of_usage

    finddepth(\&wanted0, $FindBin::RealBin);
    print "\n";
    exit;
}

sub wanted0{
    if($File::Find::dir eq $FindBin::RealBin
            and -d $File::Find::name
            and !/^\.|dev|test|lib/i){
        print "    ".join(" ", $FindBin::Script, $_)."\n";
    }
}

############################################################
#                        SUB-USAGE                         #
############################################################

sub sub_usage{
    my $dir = shift @ARGV;
    die qq/Directory $dir was not found.\n/
        unless -e qq|$FindBin::RealBin/$dir|
            and !/^\.|dev|test|lib/;
    print <<"end_of_usage";

NAME
    $FindBin::Script $dir

AVAILABE SCRIPTS
end_of_usage
    find(\&wanted1, "$FindBin::RealBin/$dir");
    exit;
}

sub wanted1{
    if(/\.pl$/){
        my $dir = basename $File::Find::dir;
        my $name = substr $_, 0, -3;
        print "    ".join(" ", $FindBin::Script, $dir, $name)."\n";
    }
}

############################################################
#                         MAIN                             #
############################################################

sub main{
    if(@ARGV == 0){ main_usage }
    if(@ARGV == 1){ sub_usage  }
    elsif(@ARGV > 1){
        my $dir = shift @ARGV;
        my $name = shift @ARGV;
        $name .= ".pl" if $name !~ /\.pl$/;
        die qq/Script "$FindBin::Script $dir $name" was not found.\n/
            unless -e "$FindBin::RealBin/$dir/$name";
        system("$FindBin::RealBin/$dir/$name @ARGV");
    }
}

main unless caller;
