Perl-one-liners
======

Collection of tricks of Perl one-liners

Print hello world

    perl -e 'print "Hello world!\n"'
    perl -le 'print qq/Hello world!/'

Grep-like pattern searcher

    cat input.txt | perl -ne 'print if /regex/'
    seq 1 100 | perl -ne 'print if /^9/'
    seq 1 100 | perl -ne 'print if /9$/'

Sed-like string replacement

    cat input.txt | perl -pe 's/old/new/'
    seq 1 10 | perl -pe 's/1/one/'

Exchange first and second column

    cat input.txt | perl -alne 'print "$F[1]\t$F[0]"'
    seq 1 10 | paste - - | perl -alne 'print "$F[1]\t$F[0]"'
    seq 1 10 | paste - - | perl -alne 'print join("\t", @F[1,0])'
    seq 1 10 | paste - - | perl -alne 'print join(chr(9), @F[1,0])'
    seq 1 10 | paste - - | perl -alne 'print join(chr 9, @F[1,0])'
    seq 1 10 | paste - - | perl -alne 'print join chr 9, @F[1,0]'

Print the length of each line

    cat input.txt | perl -lne 'print length($_)'
    seq 1 10 | perl -lne 'print length($_)'

Split a text file into characters and count the number of them

    cat input.txt | perl -pe 's//\n/g' | sort | uniq -c
    seq 1 10 | perl -pe 's//\n/g' | sort | uniq -c

Print the sum of a list of numbers

    seq 1 100 | perl -lne '$sum += $_; END{print $sum}'
    seq 1 100 | perl -lne 'BEGIN {print qq/Sum: /} $sum += $_; END{print $sum}'
    seq 1 100 | perl -ne 'BEGIN {print qq/Sum: /} $sum += $_; END{print "$sum\n"}'
    seq 1 100 | perl -nE 'BEGIN {print qq/Sum: /} $sum += $_; END{say $sum}'

Min, max, sum, mean of a list of number using [datamash](http://www.gnu.org/software/datamash/)

    seq 1 100 | datamash --header-out min 1 max 1 sum 1 mean 1

