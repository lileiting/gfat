package message;
use warnings;
use strict;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(msg);
@EXPORT_OK = @EXPORT;

sub msg{local $\ = "\n"; print STDERR @_}

1;
