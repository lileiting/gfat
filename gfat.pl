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
\nNAME
    $FindBin::Script - Gene Family Analysis Tools
\nAVAILABLE CATEGORIES
end_of_usage

    for my $dir (glob "$FindBin::RealBin/*"){
        next unless -d $dir;
        $dir = basename $dir;
        next if $dir =~ /^\.|dev|test|lib/i;
        print "    $dir\n";
    }

    print "\n";
    exit;
}

############################################################
#                        SUB-USAGE                         #
############################################################

sub sub_usage{
    my $dir = shift @ARGV;
    die "Directory $dir was not found.\n"
        unless -d "$FindBin::RealBin/$dir";
    exit if $dir =~ /^\.|dev|test|lib/;
    print <<"end_of_usage";
\nNAME
    $FindBin::Script $dir
\nAVAILABE SCRIPTS
end_of_usage
    find(\&wanted1, "$FindBin::RealBin/$dir");
    print "\n";
    exit;
}

sub wanted1{
    if(/\.pl$/){
        my $dir = basename $File::Find::dir;
        my $action_name = substr $_, 0, -3;
        print "    ".join(" ", 
            $FindBin::Script, 
            $dir, 
            $action_name)."\n";
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
        die "Script $FindBin::RealBin/$dir/$name was not found.\n"
            unless -e "$FindBin::RealBin/$dir/$name";
        system("perl $FindBin::RealBin/$dir/$name @ARGV");
    }
}

main unless caller;
