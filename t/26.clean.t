use strict;
use warnings;
use File::Spec;
use Test::More;

plan tests => 1;

my $datadir = File::Spec->catdir(qw[. data]);
my $dbname = File::Spec->catfile(qw[. data test.db]);
-d $datadir or mkdir $datadir;
-e $dbname and unlink $dbname;

ok 'data clean.';

