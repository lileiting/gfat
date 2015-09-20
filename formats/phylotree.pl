#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use Bio::TreeIO;

my $USAGE = "fa_tree_reformat.pl -if INFORMAT -of OUTFORMAT -i FILENAME -o output.FORMAT

-h/--help               Print this help
-if/--informat          Specify the input format
-of/--outformat         Specify the output format
-i/--input              Specify the input file name
                        (to pass in data on STDIN use minus sign as filename)
-o/--output             Specify the output file name
                        (to pass data out on STDOUT use minus sign as filename)
";

my ($input, $output, $informat, $outformat);

GetOptions(
    'h|help'             => sub{print STDERR ($USAGE);exit(0)},
    'i|input:s'          => \$input,
    'o|output:s'         => \$output,
    'if|informat:s'      => \$informat,
    'of|outformat:s'     => \$outformat,
);

unless (defined $informat and defined $outformat){
    die(sprintf("Cannot proceed without a defined informat and outformat you gave (%s,%s)\n",
                defined $informat ? $informat : "''" ,
                defined $outformat ? $outformat : "''"));
}

my ($in, $out, @inpara, @outpara);
if($input ){@inpara  = (-file => $input    )}else{@inpara  = (-fh => \*STDIN)}
if($output){@outpara = (-file => ">$output")}else{@outpara = (-fh => \*STDOUT)}

$in  = Bio::TreeIO->new(-format => $informat,  @inpara );
$out = Bio::TreeIO->new(-format => $outformat, @outpara);

while( my $t = $in->next_tree ) {
  $out->write_tree($t);
}

__END__
# Simple form to do the same thing

#!/usr/bin/env perl


use Bio::TreeIO;
use strict;
my ($filein,$fileout) = @ARGV;
my ($format,$oformat) = qw(newick nexus);
my $in = Bio::TreeIO->new(-file => $filein, -format => $format, -bootstrap_style => 'molphy');
my $out= Bio::TreeIO->new(-format => $oformat, -file => ">$fileout");

while( my $t = $in->next_tree ) {
  $out->write_tree($t);
}
