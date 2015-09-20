package GFAT::SeqAction;

use warnings;
use strict;
use GFAT::SeqActionNew;
use GFAT::LoadFile;
use List::Util qw(sum max min);

sub acclist{
    my $action = new_seqaction(
        -description => "Print a list of accession numbers",
    );
    while( my $seq = $action->{in}->next_seq){
        print $seq->accession_number, "\n";
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
        -description => 'Get a subset of sequences from based on its IDs',
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

sub length{
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

sub sort{
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

sub subseq{
    my $action = new_seqaction(
        -description => 'Get subsequences',
        -options => {
            "seqname|s=s" => 'Sequence name',
            "start|t=i"   => 'Start position(>=1)',
            "end|e=i"     => 'End position(>=1)'
        }
    );
    my $options = $action->{options};
    my $out = $action->{out_io};
    my ($seqname, $start, $end) = @{$options}{qw/seqname start end/};
    die "ERROR in sequence name, start position and end position\n"
        unless $seqname and $start and $end;

    for my $in (@{$action->{in_ios}}){
        while(my $seq = $in->next_seq){
            my $id = $seq->display_id;
            if($id eq $seqname){
                my $subseq_id = "$id:$start-$end";
                my $subseq = $seq->subseq($start, $end);
                $out->write_seq(
                    Bio::PrimarySeq->new(-display_id => $subseq_id,
                                         -seq => $subseq));
                exit;
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
