#!/usr/bin/env perl

use warnings;
use strict;

my @pool = (1..16);
my $number = $pool[int(rand(16))];
print "A random number from 1 to 16 have been choosen!\n";

while(1){
    print "Please guess the number:";
    my $guess = <>;
    chomp $guess;
    if($guess == $number){
        print "Congratulations! The right number was $number!\n";
        exit;
    }elsif($guess > $number){
        print "Sorry, it's not the number, it's less than $guess!\n";
    }else{
        print "Sorry, it's not the number, it's greater than $guess!\n";
    }
}
