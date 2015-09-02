#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use Getopt::Long;
use Bio::Perl;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionBase qw(load_listfile);

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]

ACTION
    accession   | Print a list of the accession numbers
    annotations  | Print all available annotations
    fasta        | Convert swiss format to fasta format
    genename     | Print gene name
    getseq       | Get some sequences from a big file
    publications | Print publications for each entry

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
         &{\&{$action}}
    }else{
        print "CAUTION: Action $action was not defined!\n";
        main_usage;
    }
}

main() unless caller;

###########
# ACTIONS #
###########

sub accession_usage{
    print <<"usage";

USAGE
    $FindBin::Script accessions [OPTIONS]

DESCRIPTION
    Print a list of the accession numbers

OPTIONS
    -i,--infile FILE

usage
    exit;
}

sub accession{
    accession_usage unless @ARGV;
    my %options;
    GetOptions( \%options,
        "infile|i=s",
    );
    accession_usage unless $options{infile};
    my $stream = Bio::SeqIO->new(-file => $options{infile},
                                 -format => 'swiss');
    while( my $seq = $stream->next_seq() ){
        my $acc = $seq->accession;
        print "$acc\n";
    }
}

sub annotations_usage{
    print <<"usage";

USAGE
    $FindBin::Script annotations [OPTIONS]

DESCRIPTION
    Print all possible annotations

OPTIONS
    -i,--infile FILE

usage
    exit;
}

sub annotations{
    annotations_usage unless @ARGV;
    my %options;
    GetOptions(\%options,
        "infile|i=s",
    );
    annotations_usage unless $options{infile};

    my $stream = Bio::SeqIO->new(-file => $options{infile},
                                  -format => 'swiss');

    while( my $seq = $stream->next_seq() ){
        for my $key ( $seq->annotation->get_all_annotation_keys ) {
            my @annotations = $seq->annotation->get_Annotations($key);
            for my $value ( @annotations ) {
                print "tagname : ", $value->tagname, "\n";
                # $value is an Bio::Annotation, and also has an "as_text" method
                print "  annotation value: ", $value->display_text, "\n";
            }
        }
    }
}

sub fasta_usage{
    print <<"usage";

USAGE
    $FindBin::Script fasta [OPTIONS]

DESCRIPTION
    Convert swiss format sequences to FASTA format

OPTIONS
    -i,--infile FILE

usage
    exit;
}

sub fasta{
     fasta_usage unless @ARGV;
     my %options;
     GetOptions(\%options, 
          "infile|i=s",
     );
     fasta_usage unless $options{infile};

     my $stream = Bio::SeqIO->new(-file => $options{infile},
                                  -format => 'swiss');
     my $out    = Bio::SeqIO->new(-fh => \*STDOUT, 
                                  -format => 'fasta');

     while( my $seq = $stream->next_seq() ){
         $out->write_seq($seq);
     }
}

sub genename_usage{
    print <<"usage";

USAGE
    $FindBin::Script genename [OPTIONS]

DESCRIPTION
    Print gene names for each entry

OPTIONS
    -i,--infile FILE

usage
    exit;
}

sub genename{
     genename_usage unless @ARGV;
     my %options;
     GetOptions(\%options,
          "infile|i=s",
     );
     genename_usage unless $options{infile};

     my $stream = Bio::SeqIO->new(-file => $options{infile},
                                  -format => 'swiss');

     while( my $seq = $stream->next_seq() ){
         my $acc = $seq->accession;
         my $id = $seq->display_id;
         for my $ann ($seq->annotation->get_Annotations('gene_name')) {

             # each gene name group
             for my $node ($ann->findnode('gene_name')) {
                 print "$acc($id) Gene name:\n";

                 # each gene name node (tag => value pair)
                 for my $n ($node->children) {
                     print "\t".$n->element.": ".$n->children."\n";
                 }
             }
         }
     }
}

sub getseq_usage{
    print <<"usage";

USAGE
    $FindBin::Script getseq [OPTIONS]

DESCRIPTION
    Get some sequences from a big file

OPTIONS
    -i,--infile    FILE
    -p,--pattern   STR
    -a,--accession STR
    -l,--listfile  FILE

usage
    exit;
}

sub getseq{
    getseq_usage unless @ARGV;
    my %options;
    GetOptions( \%options,
        "infile|i=s",
        "pattern|p=s",
        "accession|a=s@",
        "listfile|l=s"
    );
    getseq_usage unless $options{infile};

    my $pattern = $options{pattern};
    my @accessions = $options{accession} ?
        split(/,/,join(',',@{$options{accession}})) : ();
    my $listfile = $options{listfile};
    die "ERROR: Pattern was not defined!\n"
        unless $pattern or @accessions or $listfile;
    my $list_ref;
    $list_ref = load_listfile($listfile) if $listfile;
    map{$list_ref->{$_}++}@accessions if @accessions;

    my $stream = Bio::SeqIO->new(-file => $options{infile},
                                 -format => 'swiss');
    my $out = Bio::SeqIO->new(-fh => \*STDOUT,
                              -format => 'swiss');

    while(my $seq = $stream->next_seq() ){
        my $seqid = $seq->accession;
        if(($pattern and $seqid =~ /$pattern/) or
            ((@accessions or $listfile) and $list_ref->{$seqid})){
            $out->write_seq($seq);
            exit if not $listfile and not $pattern and @accessions == 1;
        }
    }
}

sub publications_usage{
    print <<"usage";

USAGE
    $FindBin::Script publication [OPTIONS]

DESCRIPTION
    Print publications for each entry

OPTIONS
    -i,--infile FILE

usage
    exit;
}

sub publications{
    publications_usage unless @ARGV;
    my %options;
    GetOptions( \%options,
        "infile|i=s"
    );
    publications_usage unless $options{infile};
    my $stream = Bio::SeqIO->new(-file => $options{infile},
                                 -format => 'swiss');
    
    while( my $seq = $stream->next_seq() ){
        my $acc = $seq->accession;
        my $id = $seq->display_id;
        my $desc = $seq->description;
        my @comments = $seq->annotation->get_Annotations('comment');
        my $comments = (split /-!-/, $comments[0]->display_text)[1];
        $comments =~ s/[\s\r\n]+/ /g;
        my @references = $seq->annotation->get_Annotations('reference');
        for my $reference (@references){
            print join("\t", 
                      $acc, $id, $desc,$comments,
                      $reference->location,
                      $reference->display_text
                  ), "\n";
        }
    }
}
