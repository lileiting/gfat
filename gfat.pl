#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use File::Find;
use File::Basename;
use Text::Abbrev;

############################################################
#                       MAIN USAGE                         #
############################################################

sub main_usage{
    print <<"end_of_usage";

NAME
    $FindBin::RealScript - Gene Family Analysis Tools

AVAILABLE CATEGORIES
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

    $dir = get_full_dir_name($dir);

    print <<"end_of_usage";

NAME
    $FindBin::RealScript $dir

AVAILABE SCRIPTS
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
            $FindBin::RealScript,
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
        my $dir  = get_full_dir_name(shift @ARGV);
        my $script = get_full_script_name($dir, shift @ARGV);
        system("perl $FindBin::RealBin/$dir/$script @ARGV");
    }
}

main unless caller;

############################################################

sub get_full_dir_name{
    my $dir = shift;
    my @dir = map {basename $_} grep {-d $_ and !/^\.|dev|test|lib/}
        glob "$FindBin::RealBin/*";
    my %dir = abbrev @dir;
    $dir = $dir{$dir} // die "Directory $dir was not found.\n";
    return $dir;
}

sub get_full_script_name{
    my ($dir, $script) = @_;
    my @scripts = map {basename $_} glob "$FindBin::RealBin/$dir/*.pl";
    my %scripts = abbrev @scripts;
    $script = $scripts{$script} //
        die "Script $FindBin::RealBin/$dir/$script was not found.\n";
    return $script;
}

__END__
