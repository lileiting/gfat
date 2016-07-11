#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use File::Basename;
use Bio::SeqIO;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use List::Util qw(sum max min);
use Digest;

sub main_usage{
    my $dir = basename $FindBin::RealBin;
    print <<"end_of_usage";

USAGE
    gfat.pl $dir $FindBin::Script ACTION [OPTIONS]

ACTIONS
    acclist  | Print a list of accession numbers
    comp     | Sequence composition, #A, #T, #C, #G, etc
    clean    | Clean irregular characters
    filter   | Filter sequences by size and Number of Ns or Xs
    format   | Read in and write out sequences
    fromtab  | Convert 2-column sequence to FASTA format
    getseq   | Get sequences by IDs
    identical| Find identical records from multiple files
    ids      | Print a list of sequence IDs
    motif    | Find sequences with given sequence pattern
    oneline  | Print one sequence in one line
    rename   | Rename sequence IDs
    revcom   | Reverse complementary
    rmdesc   | Remove sequence descriptions
    seqlen   | Print a list of sequence length, N50, etc
    seqsort  | Sort sequences by name/size
    ssr      | Find simple sequence repeats (SSR)
    subseq   | Get subsequence
    subseq2  | Get subsequences based on input file (ID, start, end,
               strand, new ID)
    totab    | Convert FASTA format sequence to 2-column format
    translate| Translate CDS to protein sequences

end_of_usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $args = shift @ARGV;
    if(defined &{\&{$args}}){
        &{\&{$args}};
    }
    else{
        die "CAUTION: action $args was not defined!\n";
    }
}

main() unless caller;

############################################################
# Defination of Actions                                    #
############################################################

sub new_seqaction{
    my %args = @_;
    my $format = 'fasta';
    my $args = new_action(%args);
    for my $fh (@{$args->{in_fhs}}){
        my $in = Bio::SeqIO->new(-fh => $fh,
                                 -format => $format);
        push @{$args->{bioseq_io}}, $in;
    }
    my $out = Bio::SeqIO->new(-fh => $args->{out_fh},
                           -format => $format);
    $args->{out_io} = $out;
    return $args;
}

############################################################

sub acclist{
    my $args = new_seqaction(
        -description => "Print a list of accession numbers",
    );
    for my $in (@{$args->{bioseq_io}}){
        while( my $seq = $in->next_seq){
            print $seq->accession_number, "\n";
        }
    }
}

sub clean{
    my $args = new_seqaction(
       -description => 'Clean irregular characters'
    );
    for my $in (@{$args->{bioseq_io}}){
        while( my $seq = $in->next_seq){
            my $cleaned_seq = join('',
                grep{/[A-Za-z*]/}split(//, $seq->seq));
            $args->{out_io}->write_seq(
                Bio::PrimarySeq->new(-display_id => $seq->display_id,
                                     -description => $seq->desc,
                                     -seq => $cleaned_seq));
        }
    }
}

sub comp{
    my $args = new_seqaction(
        -desc => 'Print sequence composition'
    );
    my %allseqs;
    warn join("\t", 'seqid', 'length', '#A', '#T', '#C', '#G', 'GC(%)')."\n";
    warn '-' x 60, "\n";
    for my $in (@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            my $seqid = $seq->display_id;
            my $seqlen = $seq->length;
            $allseqs{seqlen} += $seqlen;
            my $seqstr = $seq->seq;
            my %nt;
            map{$nt{"\u$_"}++} split //, $seqstr;
            map{$nt{$_} //= 0}qw/A T C G/;
            map{$allseqs{$_} += $nt{$_}}qw/A T C G/;
            print join("\t", $seqid, $seqlen, @nt{qw/A T C G/},
                sprintf("%.1f", sum(@nt{qw/G C/}) / sum(@nt{qw/A T C G/}) * 100)
            )."\n";
        }
    }
    warn '-' x 60, "\n";
    warn join("\t", 'Sum', $allseqs{seqlen}, @allseqs{qw/A T C G/}, 
        sprintf("%.1f", 
            sum(@allseqs{qw/G C/}) / sum(@allseqs{qw/A T C G/}) * 100
        ))."\n";
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
    for my $in (@{$args->{bioseq_io}}){
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
    my $args = new_seqaction(
        -description => 'Read in and write out sequences'
    );
    for my $in (@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            $args->{out_io}->write_seq($seq);
        }
    }
}


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

sub getseq{
    my $args = new_seqaction(
        -description => 'Get a subset of sequences from input files based
                         on given sequence IDs or a name pattern',
        -options => {
            'pattern|p=s'    => 'Pattern for sequence IDs',
            'seqname|s=s@'   => 'sequence name (could be multiple)',
            'listfile|l=s'   => 'A file contains a list of sequence IDs',
            'invert_match|v' => 'Invert match',
            'order|O=i'      => 'Output sequence order: 
                                 0 (default, order in input sequence file);
                                 1 (order in listfile/seqname/pattern)'
        }
    );
    my $out = $args->{out_io};
    my $pattern      = $args->{options}->{pattern};
    my @seqnames     = $args->{options}->{seqname} ?
        split(/,/,join(',',@{$args->{options}->{seqname}})) : ();
    my $listfile     = $args->{options}->{listfile};
    my $invert_match = $args->{options}->{invert_match};
    my $order        = $args->{options}->{order} // 0;
    die "WARNING: Pattern was not defined!\n"
        unless $pattern or @seqnames or $listfile;
    die "WARNING: '-O' should be 0 or 1\n" unless $order == 0 or $order == 1;
    die "WARNING: not logical for '-v -O 1'\n" if $invert_match and $order == 1;

    my %seqname;
    map{$seqname{$_}++}@seqnames;

    my @genelist;
    my %genelist;
    if($listfile){
        open my $fh, $listfile or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            chomp;
            @_ = split /\t/;
            push @genelist, $_[0];
            $genelist{$_[0]}++;
        }
        close $fh;
    }

    my %matched_seq; # seq object as value
    my @pattern_matched;
    for my $in (@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            my $seqid = $seq->display_id;
            my $s = 0b000; # matched status
            $s = $s | 0b001 if $pattern and $seqid =~ /$pattern/;
            $s = $s | 0b010 if @seqnames and $seqname{$seqid};
            $s = $s | 0b100 if $listfile and $genelist{$seqid};
            $s = not $s if $invert_match;
            next if $s == 0b000;
            if($order == 0){
                $out->write_seq($seq);
            }
            else{
                $matched_seq{$seqid}  = $seq;
                push @pattern_matched, $seqid if $s == 0b001;
            }
        }
    }
    return 1 if $order == 0;
    for my $seqid (@genelist, @seqnames, @pattern_matched){
        $out->write_seq($matched_seq{$seqid});
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
    for my $in_io (@{$args->{bioseq_io}}){
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

sub ids{
    my $args = new_seqaction(
        -description => 'Print a list of sequence IDs',
        -options     => {
            "description|d" => 'Print a second column for descriptions',
            "until|u=s"     => 'Truncate the name and description at words'
        }
    );
    for my $in (@{$args->{bioseq_io}}){
        while( my $seq = $in->next_seq ){
            my $info = $seq->display_id .
                ($args->{options}->{description} ? "\t".$seq->desc : '');
            my $re = $args->{options}->{until};
            $info =~ s/$re.*$// if defined $re;
            print "$info\n";
        }
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

    for my $in (@{$args->{bioseq_io}}){
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

sub oneline{
    my $args = new_seqaction(
        -description => 'Print one sequence in one line'
    );
    my $options = $args->{options};

    for my $in (@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            my $id = $seq->display_id;
            my $desc = " ".$seq->desc;
            my $seq = $seq->seq;
            print ">$id$desc\n$seq\n";
        }
    }
}

sub rename{
    my $args = new_seqaction(
        -description => "Rename sequence IDs",
        -options => {
            "from|f=s" => 'From which string',
            "to|t=s"   => 'To which string'
        }
    );
    my ($from, $to) = @{$args->{options}}{qw/from to/};
    die "CAUTION: FROM or TO was not defined!"
        unless defined $from and defined $to;
    for my $in(@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            my $id = $seq->display_id;
            $id =~ s/$from/$to/;
            $args->{out_io}->write_seq(
                Bio::PrimarySeq->new(-display_id => $id,
                                     -seq => $seq->seq));
        }
    }
}

sub revcom{
    my $args = new_seqaction(
        -description => 'Reverse complementary'
    );
    for my $in(@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            $args->{out_io}->write_seq(Bio::Perl::revcom($seq));
        }
    }
}

sub rmdesc{
    my $args = new_seqaction(
        -description => 'Remove sequence descriptions'
    );
    for my $in(@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            $args->{out_io}->write_seq(
                Bio::PrimarySeq->new(-display_id => $seq->display_id,
                                     -seq => $seq->seq));
        }
    }
}

sub seqlen {
    my $args = new_seqaction(
        -description => 'Print a list of sequence length',
    );
    my @lengths;
    for my $in (@{$args->{bioseq_io}}){
        while( my $seq = $in->next_seq ){
            print $seq->display_id, "\t", $seq->length, "\n";
            push @lengths, $seq->length;
        }
    }
    @lengths = sort {$b <=> $a} @lengths;
    my $num_of_seq = scalar @lengths;
    my $total_length = sum @lengths;
    my $max_length = max @lengths;
    my $min_length = min @lengths;
    my $avg_length = sprintf "%.1f", $total_length / $num_of_seq;
    my $sum = 0;
    my $N50 = 0;
    my $L50 = 0;
    foreach my $len (@lengths){
        $N50++;
        $sum += $len;
        $L50 = $len;
        last if $sum >= $total_length / 2;
    }
    die if $L50 eq 'L50';
    die "CAUTION: No sequences!" unless @lengths;
    warn "Number of sequences: ", scalar(@lengths), "\n";
    warn "Total length: $total_length\n";
    warn "Maximum length: $max_length\n";
    warn "Minimum length: $min_length\n";
    warn "Average length: $avg_length\n";
    warn "N50: $N50\n";
    warn "L50: $L50\n";
}

sub seqsort{
    my $args = new_seqaction(
        -description => 'Sort sequences by name/size',
        -options => {
            "sizes|s" => 'Sort by sizes (default by ID name)'
        }
    );
    my @seqobjs;
    for my $in (@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            push @seqobjs, $seq;
        }
    }
    map{$args->{out_io}->write_seq($_)}( sort{ $args->{options}->{sizes} ?
            $b->length <=> $a->length :
            $a->display_id cmp $b->display_id
        }@seqobjs);
}

sub ssr{
    my $args = new_seqaction(
        -description => 'Find simple sequence repeats (SSR)'
    );
    my $options = $args->{options};
    # Defination of SSR:
    # Repeat unit 2bp to 6bp, length not less than 18bp
    my ($id, $flank_seq_length) = (0, 100);
    print join("\t",
        qw/ID          Seq_Name           Start
           End         SSR                Length
           Repeat_Unit Repeat_Unit_Length Repeatitions
           Sequence/
        )."\n";
    for my $in (@{$args->{bioseq_io}}){
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
    my $args = new_seqaction(
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
    my $options = $args->{options};
    my $out = $args->{out_io};
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

    for my $in (@{$args->{bioseq_io}}){
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
    for my $in (@{$args->{bioseq_io}}){
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

    for my $in_io (@{$args->{bioseq_io}}){
        while(my $seq = $in_io->next_seq){
            print $seq->display_id,
                  "\t", $seq->seq,
                  $print_desc ? "\t".$seq->desc : '',
                  "\n";
        }
    }
}

sub translate{
    my $args = new_seqaction(
        -description => 'Translate CDS to protein sequences'
    );
    for my $in (@{$args->{bioseq_io}}){
        while(my $seq = $in->next_seq){
            #my $pep = translate($seq);
            $args->{out_io}->write_seq(Bio::Perl::translate($seq));
        }
    }
}

__END__
