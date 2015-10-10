package GFAT::SeqAction;

use warnings;
use strict;
use List::Util qw(sum max min);
use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha1_hex);
use Data::Dumper;
use GFAT::SeqActionNew;
use GFAT::LoadFile;

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
            'listfile|l=s' => 'A file contains a list of sequence IDs'
        }
    );
    my $options = $action->{options};
    my $out = $action->{out_io};
    my $pattern = $options->{pattern};
    my @seqnames = $options->{seqname} ?
        split(/,/,join(',',@{$options->{seqname}})) : ();
    my $listfile = $options->{listfile};
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
                $out->write_seq($seq);
                exit if not $listfile and not $pattern and @seqnames == 1;
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

sub identical{
    my $args = new_seqaction(
        -desc => 'Find identical records from multipls files,
                  based sequence fingerprints (MD5)'
    );
    #die Dumper($args);

    my %data;
    my $index = 0;
    for my $in_io (@{$args->{in_ios}}){
        my $infile = $args->{infiles}[$index];
        $index++;
        while(my $seq = $in_io->next_seq){
            print $seq->display_id, "\t", $infile, "\t",
                  $seq->length, "\t",
                  md5_hex($seq->seq), "\t", sha1_hex($seq->seq), "\n"; 
        }

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

sub motif{
    my $action = new_seqaction(
        -description => 'Find sequences with given sequence pattern',
        -options => {
            "pattern|p=s" => 'Sequence pattern'
        }
    );
    my $options = $action->{options};
    my $out = $action->{out_io};
    my $pattern = $options->{pattern};
    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $seqstr = $seq->seq;
            $out->write_seq($seq) if $seqstr =~ /$pattern/;
        }
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

1;
