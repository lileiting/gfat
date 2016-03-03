#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use File::Basename;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use GFAT::SeqActionNew;
use List::Util qw(sum max min);
use Digest;
use Data::Dumper;
use GFAT::LoadFile;


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

sub acclist{
    my $action = new_seqaction(
        -description => "Print a list of accession numbers",
    );
    for my $in (@{$action->{in_ios}}){
        while( my $seq = $in->next_seq){
            print $seq->accession_number, "\n";
        }
    }
}

sub clean{
    my $action = new_seqaction(
       -description => 'Clean irregular characters'
    );
    for my $in (@{$action->{in_ios}}){
        while( my $seq = $in->next_seq){
            my $cleaned_seq = join('',
                grep{/[A-Za-z*]/}split(//, $seq->seq));
            $action->{out_io}->write_seq(
                Bio::PrimarySeq->new(-display_id => $seq->display_id,
                                     -description => $seq->desc,
                                     -seq => $cleaned_seq));
        }
    }
}

sub filter{
    my $args = new_seqaction(
        -desc => "Filter the sequence file to contain records with
                  size >= or < certain cutoff, or filter out
                  sequences with too many Ns or Xs.",
        -options => {
            "size|s=i" => 'Minimum sequence size (default: 0, do nothing)',
            "char|c=i" => 'Maximum number of Ns or Xs (default: -1, no limit)',
                    }
    );

    my $size         = $args->{options}->{size} // 0;
    my $char         = $args->{options}->{char} // -1;

    my $report = '';
    for my $in (@{$args->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $seqid = $seq->display_id;
            my $seqlen = $seq->length;
            unless($seqlen >= $size){
                $report .= "$seqid\tlength=$seqlen\n";
                next;
            }

            if($char >= 0){
                my $seqirr = 0;
                my $seqstr = $seq->seq;
                $seqirr++ while $seqstr =~ /[NnXx]/g;
                unless($seqirr <= $char){
                    $report .= "$seqid\tNnXx=$seqirr\n";
                    next;
                }
            }
            $args->{out_io}->write_seq($seq);
        }
    }
    warn $report;
}

sub format{
    my $action = new_seqaction(
        -description => 'Read in and write out sequences'
    );
    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            $action->{out_io}->write_seq($seq);
        }
    }
}

sub _count_gc{
    my $str = shift;
    my @char = split //, $str;
    my %char;
    map{$char{$_}++}@char;
    my $gc = ($char{G} // 0) + ($char{C} // 0);
    my $at = ($char{A} // 0) + ($char{T} // 0);
    return ($gc, $at);
}

sub gc{
    my $action = new_seqaction(
        -description => 'GC content'
    );
    my $options = $action->{options};
    my $total_len = 0;
    my $gc = 0;
    my $at = 0;
    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            $total_len += $seq->length;
            my ($seq_gc, $seq_at) = _count_gc($seq->seq);
            $gc += $seq_gc;
            $at += $seq_at;
        }
    }
    printf "GC content: %.2f %%\n", $gc / ($gc+$at) * 100;
    my $non_atgc = $total_len - ($gc + $at);
    printf "Non-ATGC characters: %d of %d (%.2f %%)\n",
               $non_atgc, $total_len, $non_atgc / $total_len * 100
           if $non_atgc;
}

sub getseq{
    my $action = new_seqaction(
        -description => 'Get a subset of sequences from input files based
                         on given IDs. The output sequence order will follow
                         the sequence order in input files, rather than
                         given IDs. Because "getseq" will read sequences
                         from input files, and test one by one if it was
                         the sequence you want.',
        -options => {
            'pattern|p=s' => 'Pattern for sequence IDs',
            'seqname|s=s@' => 'sequence name (could be multiple)',
            'listfile|l=s' => 'A file contains a list of sequence IDs',
            'invert_match|v' => 'Invert match'
        }
    );
    my $options = $action->{options};
    my $out = $action->{out_io};
    my $pattern = $options->{pattern};
    my @seqnames = $options->{seqname} ?
        split(/,/,join(',',@{$options->{seqname}})) : ();
    my $listfile = $options->{listfile};
    my $invert_match = $options->{invert_match};
    die "ERROR: Pattern was not defined!\n"
        unless $pattern or @seqnames or $listfile;
    my $list_ref;
    $list_ref = load_listfile($listfile) if $listfile;
    map{$list_ref->{$_}++}@seqnames if @seqnames;
    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $seqid = $seq->display_id;
            if(($pattern and $seqid =~ /$pattern/) or
                ((@seqnames or $listfile) and $list_ref->{$seqid})){
                $out->write_seq($seq) if not $invert_match;
                exit if not $listfile and not $pattern and @seqnames == 1;
            }else{
                $out->write_seq($seq) if $invert_match;
            }
        }
    }
}

sub getseq2{
    my $args = new_seqaction(
        -desc => '"getseq2" is similar with another "getseq", with a little
                  differnt. The purpose of "getseq2" is to get sequences
                  based on given IDs and output sequences based on the order
                  of input IDs. "getseq2" will first load all input sequences
                  from input files into memory. So do not use this "getseq2"
                  on files larger than your computer memory.',
        -options => {
            "file|f=s" => 'A list of Sequence IDs, one per line',
            "seqname|s=s@" => 'Sequence ID (could be multiple)'
                    }
    );
    my $options = $args->{options};
    my $listfile = $options->{file};
    my @seqnames = $options->{seqname} ?
        split(/,/,join(',',@{$options->{seqname}})) : ();
    die "ERROR: Sequence ID was not defined!\n"
        unless @seqnames or $listfile;
    my %id_map;
    for my $in (@{$args->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $seqid = $seq->display_id;
            $id_map{$seqid} = $seq;
        }
    }
    my @file_IDs;
    open my $fh, "$listfile" or die "$!";
    chomp(@file_IDs = <$fh>);
    close $fh;
    for (@seqnames, @file_IDs){
        $args->{out_io}->write_seq($id_map{$_});
    }
}

sub ids{
    my $action = new_seqaction(
        -description => 'Print a list of sequence IDs',
        -options     => {
            "description|d" => 'Print a second column for descriptions',
            "until|u=s"     => 'Truncate the name and description at words'
        }
    );
    for my $in (@{$action->{in_ios}}){
        while( my $seq = $in->next_seq ){
            my $info = $seq->display_id .
                ($action->{options}->{description} ? "\t".$seq->desc : '');
            my $re = $action->{options}->{until};
            $info =~ s/$re.*$// if defined $re;
            print "$info\n";
        }
    }
}

sub _calculate_N50{
    my @num = sort{$b <=> $a}@_;
    my $total = sum(@num);
    my $sum = 0;
    my $n = 0;
    for my $len (@num){
        $n++;
        $sum += $len;
        return ($n, $len) if $sum >= $total / 2;
    }
}

sub oneline{
    my $action = new_seqaction(
        -description => 'Print one sequence in one line'
    );
    my $options = $action->{options};

    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $id = $seq->display_id;
            my $desc = " ".$seq->desc;
            my $seq = $seq->seq;
            print ">$id$desc\n$seq\n";
        }
    }
}

sub rename{
    my $action = new_seqaction(
        -description => "Rename sequence IDs",
        -options => {
            "from|f=s" => 'From which string',
            "to|t=s"   => 'To which string'
        }
    );
    my ($from, $to) = @{$action->{options}}{qw/from to/};
    die "CAUTION: FROM or TO was not defined!"
        unless defined $from and defined $to;
    for my $in(@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $id = $seq->display_id;
            $id =~ s/$from/$to/;
            $action->{out_io}->write_seq(
                Bio::PrimarySeq->new(-display_id => $id,
                                     -seq => $seq->seq));
        }
    }
}

sub revcom{
    my $action = new_seqaction(
        -description => 'Reverse complementary'
    );
    for my $in(@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            $action->{out_io}->write_seq(Bio::Perl::revcom($seq));
        }
    }
}

sub rmdesc{
    my $action = new_seqaction(
        -description => 'Remove sequence descriptions'
    );
    for my $in(@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            $action->{out_io}->write_seq(
                Bio::PrimarySeq->new(-display_id => $seq->display_id,
                                     -seq => $seq->seq));
        }
    }
}

sub seqlen {
    my $action = new_seqaction(
        -description => 'Print a list of sequence length',
        -options     => {
            "summary|s" => 'Print summary of sequence length'
        }
    );
    my @lengths;
    for my $in (@{$action->{in_ios}}){
        while( my $seq = $in->next_seq ){
            print $seq->display_id, "\t", $seq->length, "\n";
            push @lengths, $seq->length if $action->{options}->{summary};
        }
    }
    if($action->{options}->{summary}){
        die "CAUTION: No sequences!" unless @lengths;
        warn "Number of sequences: ", scalar(@lengths), "\n";
        warn "Total length: ", sum(@lengths), "\n";
        warn "Maximum length: ", max(@lengths), "\n";
        warn "Minimum length: ", min(@lengths), "\n";
        warn "Average length: ", sum(@lengths) / scalar(@lengths), "\n";
        my ($N50, $L50) = _calculate_N50(@lengths);
        warn "N50: $N50\n";
        warn "L50: $L50\n";
    }
}

sub seqsort{
    my $action = new_seqaction(
        -description => 'Sort sequences by name/size',
        -options => {
            "sizes|s" => 'Sort by sizes (default by ID name)'
        }
    );
    my @seqobjs;
    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            push @seqobjs, $seq;
        }
    }
    map{$action->{out_io}->write_seq($_)}( sort{ $action->{options}->{sizes} ?
            $b->length <=> $a->length :
            $a->display_id cmp $b->display_id
        }@seqobjs);
}

sub ssr{
    my $action = new_seqaction(
        -description => 'Find simple sequence repeats (SSR)'
    );
    my $options = $action->{options};
    # Defination of SSR:
    # Repeat unit 2bp to 6bp, length not less than 18bp
    my ($id, $flank_seq_length) = (0, 100);
    print join("\t",
        qw/ID          Seq_Name           Start
           End         SSR                Length
           Repeat_Unit Repeat_Unit_Length Repeatitions
           Sequence/
        )."\n";
    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            my ($sequence, $seq_name) = ($seq->seq, $seq->display_id);
            while($sequence =~ /(([ATGC]{2,6}?)\2{3,})/g){
                my ($match, $repeat_unit) = ($1, $2);
                my ($repeat_length, $SSR_length)=
                    (length($repeat_unit), length($match));
                if($match =~ /([ATGC])\1{5}/){next;}
                $id++;
                print join("\t",
                    $id,
                    $seq_name,
                    pos($sequence)-$SSR_length+1,
                    pos($sequence),
                    $match,
                    $SSR_length,
                    $repeat_unit,
                    $repeat_length,
                    $SSR_length / $repeat_length,
                    substr($sequence,
                        pos($sequence) - $SSR_length - $flank_seq_length,
                        $SSR_length + $flank_seq_length * 2)
                )."\n";
            }
        }
    }
}

sub subseq{
    my $action = new_seqaction(
        -description => 'Get subsequences',
        -options => {
            "file|f=s"    => 'A file containing gene IDs with positions
                              (Start and End), strand (4th column) is optional,
                              description (5th column) is optional',
            "seqname|s=s" => 'Sequence name',
            "start|t=i"   => 'Start position(>=1)',
            "end|e=i"     => 'End position(>=1)'
        }
    );
    my $options = $action->{options};
    my $out = $action->{out_io};
    my $infile = $options->{file};
    my ($seqname, $start, $end) = @{$options}{qw/seqname start end/};
    die "ERROR in sequence name, start position and end position\n"
        unless ($seqname and $start and $end) or $infile;

    my %seqpos;
    if($seqname and $start and $end){
        $seqpos{$seqname} = [$start, $end];
    }
    if($infile){
        open my $fh, $infile or die "$!";
        while(<$fh>){
            chomp;
            die "Input data ERROR in $_! Required format ".
                "is \"ID\tStart\tEnd (and optional strand and description)\""
                unless /^\S+\t\d+\t\d+(\t[+\-])?/;
            @_ = split /\t/;
            $seqpos{$_[0]} = [@_[1..$#_]];
        }
        close $fh;
    }

    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $id = $seq->display_id;
            if($seqpos{$id}){
                my $start = $seqpos{$id}->[0];
                my $end   = $seqpos{$id}->[1];
                my $subseq_id = "$id:$start-$end";
                my $subseq;
                if($seqpos{$id}->[2] and $seqpos{$id}->[2] eq '-'){
                    $subseq = $seq->subseq($end, $start);
                }else{
                    $subseq = $seq->subseq($start, $end);
                }

                $out->write_seq(
                    Bio::PrimarySeq->new(-display_id => $subseq_id,
                                         -desc => $seqpos{$id}->[3] // '',
                                         -seq => $subseq));
            }
        }
    }
}

sub subseq2{
    my $args = new_seqaction(
        -desc => 'Get subsequences based an input file containing a list of
                  seuqence ID, start position, end position, strand, new ID',
        -options => {
                     "file|f=s" => 'a list of seuqence ID, start position,
                                    end position, strand, new ID'
                    }
    );
    my $listfile = $args->{options}->{file};
    my $out = $args->{out_io};

    my %seqs;
    for my $in (@{$args->{in_ios}}){
        while(my $seq = $in->next_seq){
            $seqs{$seq->display_id} = $seq;
        }
    }

    open my $fh, $listfile or die $!;
    while(<$fh>){
        die "Format error: $_" unless /^(\S+)\t(-?\d+)\t(\d+)\t([+\-])\t(\S+)$/;
        my ($chr, $start, $end, $strand, $new_id) =
            ($1, $2, $3, $4, $5);
        die "Start pos should be less than or equal to end pos : $_" if $start > $end;
        die "$chr not found" unless $seqs{$chr};
        $start = 1 if $start < 1;
        $end = $seqs{$chr}->length if $end > $seqs{$chr}->length;
        $out->write_seq(
              Bio::PrimarySeq->new(-display_id => $new_id,
                                   -desc => "$chr:$start-$end|$strand",
                                   -seq => $strand eq '+' ? $seqs{$chr}->subseq($start, $end)
                                                           : $seqs{$chr}->subseq($end, $start)
                                 ));
    }
    close $fh;
}

sub translate{
    my $action = new_seqaction(
        -description => 'Translate CDS to protein sequences'
    );
    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            #my $pep = translate($seq);
            $action->{out_io}->write_seq(Bio::Perl::translate($seq));
        }
    }
}

__END__
