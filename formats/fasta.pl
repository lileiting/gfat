#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use File::Basename;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use GFAT::SeqActionNew;
use GFAT::SeqAction;

sub main_usage{
    my $category = basename $FindBin::RealBin;
    print <<"usage";

USAGE
    gfat.pl $category $FindBin::Script ACTION [OPTIONS]

ACTIONS
    acclist  | Print a list of accession numbers
    clean    | Clean irregular characters
    filter   | Filter sequences by size and Number of Ns or Xs
    format   | Read in and write out sequences
    fromtab  | Convert 2-column sequence to FASTA format
    gc       | GC content
    getseq   | Get sequences by IDs
    getseq2  | Output sequences by the order of input IDs
    identical| Find identical records from multiple files
    ids      | Print a list of sequence IDs
    motif    | Find sequences with given sequence pattern
    oneline  | Print one sequence in one line
    rename   | Rename sequence IDs
    revcom   | Reverse complementary
    rmdesc   | Remove sequence descriptions
    seqlen   | Print a list of sequence length
    seqsort  | Sort sequences by name/size
    ssr      | Find simple sequence repeats (SSR)
    subseq   | Get subsequence
    subseq2  | Get subsequences based on input file (ID, start, end,
               strand, new ID)
    totab    | Convert FASTA format sequence to 2-column format
    translate| Translate CDS to protein sequences

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    our $format = 'fasta';
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}}; 
    }
    elsif(GFAT::SeqAction->can($action)){
        GFAT::SeqAction->$action();
    }
    else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main() unless caller;

############################################################
# Defination of Actions                                    #
############################################################

sub fromtab{
    my $args = new_action(
        -desc => 'Convert 2-column sequence to FASTA format
                  [Copied function from tanghaibao\'s
                   python -m jcvi.formats.fasta fromtab]',
        -options => {
            "sep|s=s" => 'Separator in the tabfile [default: tab]',
            "replace|r=s" => 'Replace spaces in name to char 
                              [default: none]',
            "length|l=i" => 'Output sequence length per line 
                             [default: unlimited]',
            "fasta|f"    => 'A shortcut for --length=60'
                    }
    );

    my $options = $args->{options};

    my $sep     = $options->{sep} // "\t";
    my $replace = $options->{replace};
    my $length  = $options->{length};
    my $fasta   = $options->{fasta};

    $length = 60 if $fasta and not $length;

    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            chomp;
            my ($id, $seq) = split /$sep/;
            $id =~ s/ /$replace/g if $replace;
            if($length){
                $seq =~ s/(.{$length})/$1\n/g;
                chomp $seq;
            }
            print ">$id\n$seq\n";
        }
    }
}

sub _first_gene_id{
    my ($checksum, $data_ref) = @_;
    if($data_ref->{$checksum}->[0]){
        return $data_ref->{$checksum}->[0][0];
    }else{
        return 'undef';
    }
}

sub identical{
    my $args = new_seqaction(
        -desc => 'Find identical records from multipls files,
                  based on sequence fingerprints (MD5)',
        -options => {
            "ignore_case|C" => 'Ignore case when comparing sequences
                                (default: False)',
            "ignore_N|N"    => 'Ignore N or X characters when 
                                comparing sequences (default: False)',
            "ignore_stop|S" => 'Ignore stop codon (remove the last 
                                character \"*\" if present) (default:
                                False)',
            "checksum|M=s"  => 'Checksum method, could be MD5, SHA-1, 
                                SHA-256, SHA-384, SHA-512, or CRC if
                                Digest::CRC was installed',
            "pchecksum|P"   => 'Print checksum (hexadecimal form) 
                                string as the second column in result 
                                file',
            "no_seqlen|L"   => 'Do not print sequence length (default: 
                                print sequence length as second column)',
            "uniq|u"        => 'Print unique sequences only',
#            "output_uniq|U=s"=> 'Output uniq sequneces. Conflict 
#                                sequence IDs will combined as new 
#                                sequence ID'
                    }
    );
    #die Dumper($args);

    my $ignore_case = $args->{options}->{ignore_case};
    my $ignore_N    = $args->{options}->{ignore_N};
    my $ignore_stop = $args->{options}->{ignore_stop};
    my $checksum_method = $args->{options}->{checksum} // 'MD5';
    my $print_checksum = $args->{options}->{pchecksum};
    my $output_uniq = $args->{options}->{output_uniq};
    my $no_seqlen = $args->{options}->{no_seqlen};
    my $print_uniq = $args->{options}->{uniq};

    my %data;
    my %seq_length;
    my $index = -1;
    for my $in_io (@{$args->{in_ios}}){
        $index++;
        my $file = $args->{infiles}[$index];
        while(my $seq = $in_io->next_seq){
            my $seqstr = $seq->seq;
            $seqstr = "\L$seqstr\E" if $ignore_case;
            $seqstr =~ s/[NnXx]//g if $ignore_N;
            $seqstr =~ s/\*$// if $ignore_stop;
            my $ctx = Digest->new($checksum_method);
            $ctx->add($seqstr);
            my $checksum = $ctx->hexdigest;
            push @{$data{$checksum}->[$index]}, $seq->display_id;
            unless(exists $seq_length{$checksum}){
                $seq_length{$checksum} = length($seqstr);
            }
            else{
                die "ERROR: SAME CHECKSUM, DIFFERENT SEQUENCE LENGTH!!!\n". 
                    "  $checksum: ". $seq->display_id . "\n"
                    unless length($seqstr) == $seq_length{$checksum};
            }
        }
    }
#    my $uniq_fh;
#    if($output_uniq){
#        open $uniq_fh, ">", $output_uniq or die "$!";
#    }

    print "\t",join("\t", "SeqLength", @{$args->{infiles}}),"\n";
    my $count = -1;
    for my $checksum ( sort {_first_gene_id($a, \%data) cmp 
                             _first_gene_id($b, \%data) }keys %data){
        my $row;
        $count++;
        $row .= "t$count";
        $row .= "\t$checksum" if $print_checksum;
        $row .= "\t".$seq_length{$checksum} unless $no_seqlen;
        my $not_uniq = 1;
        for my $i (0..$index){
            my $gene_ids = join(",", @{ $data{$checksum}->[$i] 
                                     // ['na'] });
            $not_uniq = 0 if $gene_ids eq 'na';
            $row .= "\t$gene_ids";
        }
        $row .= "\n";
        next if $print_uniq and $not_uniq;
        print $row;
    }
}

sub motif{
    my $args = new_seqaction(
        -description => 'Find sequences with given sequence pattern',
        -options => {
            "pattern|p=s" => 'Sequence pattern',
            "summary|s" => 'Print summary information, 
                          rather than sequence only'
        }
    );
    my $out = $args->{options}->{out_io};
    my $pattern = $args->{options}->{pattern};
    my $print_summary = $args->{options}->{summary};
    
    for my $in (@{$args->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $seqid = $seq->display_id;
            my $seqstr = $seq->seq;
            next unless $seqstr =~ /$pattern/;
            if($print_summary){
                while($seqstr =~ /($pattern)/g){
                    my $matched_str = $1;
                    my $end = pos($seqstr);
                    my $start = $end - length($matched_str) + 1;
                    print join("\t", $seqid, $pattern, $matched_str,
                         $start, $end
                        )."\n";
                }
            }
            else{
                $out->write_seq($seq);
            }
        }
    }
}

sub totab{
    my $args = new_seqaction(
        -desc => 'Convert FASTA format sequence to 2-column format. 
                  This is a reverse action of "fromtab"',
        -options => {
            "desc|d" => 'Print description in the third column 
                         [default: not]'
                    }
    );

    my $print_desc = $args->{options}->{desc};

    for my $in_io (@{$args->{in_ios}}){
        while(my $seq = $in_io->next_seq){
            print $seq->display_id, 
                  "\t", $seq->seq, 
                  $print_desc ? "\t".$seq->desc : '',
                  "\n";
        }
    }
}

__END__
