=head1 NAME

Formats::Cmd::Base - Base modules that used for build commands

=head1 SYNOPSIS

  use Formats::Cmd::Base qw(get_fh close_fh get_options);

  # For simple options with only input, output and help
  my $cmd = shift @ARGV // die;
  my ($in_fh, $out_fh) = get_fh($cmd);
  ...
  close_fh($in_fh, $out_fh);

  # For additional options
  my $cmd = shift @ARGV // die;
  my %options = get_options($cmd, "hello" => "Print hello world");
  my $hello = $options{hello};
  print "Hello world!\n" if $hello;

=head1 DESCRIPTION

Subroutines that assist defining commands for scripts

=head1 FEEDBACK

Create an issue in GitHub <https://github.com/lileiting/gfatk/issues>

=head1 AUTHOR

Leiting Li, Email: lileiting@gmail.com

=head1 APPENDIX

The rest of the documentation details each of the subroutine.

=cut

package Formats::Cmd::Base;
use warnings;
use strict;
use FindBin;
use Getopt::Long qw(:config no_ignore_case);
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(get_fh close_fh get_options base_main);

=head2 base_main

  Title   : base_main
  Usage   : base_main(\&functions, \&base_usage);
            base_main(\&functions, \&base_usage) unless caller;

  Function: Run functions for given command

  Returns : Nothing

  Args    : The subroutine reference for functions defination
            and the base usage subroutine reference

=cut

sub base_main{
    my ($functions_hash_ref, $base_usage_ref) = @_;
    $base_usage_ref->() unless @ARGV;
    my $cmd = shift @ARGV;
    my %functions = %$functions_hash_ref;
    $functions{$cmd} ? &{$functions{$cmd}} : 
        (warn "Unrecognized command: $cmd!\n" 
         and $base_usage_ref->());
}

=head2 key_in_opt

  Title   : key_in_opt
  Usage   : my ($long_option) = key_in_opt($opt_name);
            my ($long_option, $short_option) = key_in_opt($opt_name);

  Function: Analyze the option defination for GetOptions, like 
            "h|help", "i|input=s", "header", etc

  Returns : an array, first element is the long option, second
            element is the short option

  Args    : One string

=cut

sub key_in_opt{
    my $opt_name = shift;
    die "Option name ERROR: $opt_name!!!\n"
        unless $opt_name =~ /^(([A-Za-z])\|)?([a-z]+)(=[ifso])?$/;
    return ($3, $2 // '');
}

=head2 cmd_usage

  Title   : cmd_usage
  Usage   : cmd_usage(q/cmd/);
            cmd_usage(q/cmd/, "header" => "Print header");
            my $options = get_options(q/cmd/, "header" => "Print header",
                                              "footer" => "Print footer");

  Function: Print formated command usage

  Returns : Just exit the program

  Args    : The command name. 

=cut

sub cmd_usage{
    my ($cmd, @options) = @_;
    my @add_options = ();
    for(my $i = 0; $i < @options; $i+= 2){
        my ($opt, $desc) = @options[$i, $i+1];
        my ($long_option, $short_option) = key_in_opt($opt);
        $short_option = "-$short_option," if $short_option;
        $long_option  = "--$long_option";
        push @add_options, "    $short_option$long_option        $desc\n";
    }

    print <<USAGE;

  $FindBin::Script $cmd [OPTIONS]

    [-i,--input]  FILE
    -o,--output   FILE
    -h,--help
@add_options

USAGE
    exit;
}

=head2 get_options

  Title   : get_options
  Usage   : my $options = get_options(q/cmd/);
            my $options = get_options(q/cmd/, "header" => "Print header");
            my $options = get_options(q/cmd/, "header" => "Print header",
                                              "footer" => "Print footer");

  Function: Define options. By default, there are three options 
            available, input, output, and help. Adding additional 
            options is permitted.

  Returns : An hash reference stored option values

  Args    : The command, with or without one or more options defination 
            pairs

=cut

sub get_options{
    my ($cmd, @opt) = @_;
    my %opt;
    die "@opt" unless @opt % 2 == 0;
    my @add_options;
    for(my $i = 0; $i < @opt; $i+= 2){
        my ($opt, $desc) = @opt[$i, $i+1];
        my ($opt_name) = key_in_opt($opt);
        push @add_options, $opt, \$opt{$opt_name};
    }
    GetOptions(
        "i|input=s"  => \$opt{infile},
        "o|output=s" => \$opt{outfile},
        "h|help"     => \$opt{help},
        @add_options
    );
    cmd_usage(@_) if $opt{help} or (!$opt{infile} and @ARGV == 0 and -t STDIN);
    ($opt{in_fh}, $opt{out_fh}) = (\*STDIN, \*STDOUT);
    $opt{infile} = shift @ARGV if (!$opt{infile} and @ARGV > 0);
    open $opt{in_fh}, "<", $opt{infile} or die "$opt{infile}: $!" if $opt{infile};
    open $opt{out_fh}, ">", $opt{outfile} or die "$opt{outfile}: $!" if $opt{outfile};

    return \%opt;
}

=head2 get_fh

  Title   : get_fh
  Usage   : my ($in_fh, $out_fh) = get_fh(q/cmd/);

  Function: An shortcuts for simply get the input and output filehandles
            without additional options.

  Returns : An array contains two elements, the input filehandle, and output
            filehandle.

  Args    : A string, the command name

=cut

sub get_fh{
    my $cmd = shift;
    my $options = get_options($cmd);
    my ($in_fh, $out_fh) = @{$options}{qw/in_fh out_fh/};
    return ($in_fh, $out_fh);
}

=head2 close_fh

  Title   : close_fh
  Usage   : close_fh($in_fh, $out_fh);

  Function: Close any filehandles, except STDIN, STDOUT, and STDERR.

  Returns : 1

  Args    : An arrary contains filehandles

=cut

sub close_fh{
    my @fhs = @_;
    for my $fh (@fhs){
        close $fh unless 
               $fh eq \*STDIN  or 
               $fh eq \*STDOUT or 
               $fh eq \*STDERR;
    }
}

1;
