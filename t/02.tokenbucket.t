use strict;
use warnings;
use File::Spec;
use Test::More;
use Lamawiki;
use Lamawiki::Sqlite;
use Lamawiki::Tokenbucket;

my $true = 1==1;
my $false = 1!=1;
my $spec = [
    [0,  0, 10, $true],
    [0,  0, 15, $true],
    [0,  0, 20, $true],
    [0, 50,  0, $false],
    [1,  0,  0, $false],
    [2,  0,  0, $true],
    [2,  0, 10, $true],
    [3,  0,  0, $false],
    [4,  0,  0, $true],
    [4,  0, 10, $true],    
];

plan tests => 1 * @{$spec};

my $datadir = File::Spec->catdir(qw[. data]);
my $dbname = File::Spec->catfile(qw[. data test.db]);
-d $datadir or mkdir $datadir;
-e $dbname and unlink $dbname;

my $wiki = Lamawiki->new({
    'db' => Lamawiki::Sqlite->connect("dbi:SQLite:dbname=$dbname", q(), q(), sub{
        my($self) = @_;
        $self->fixup($self->module->{'create_table'});
    }),
    'sch' => Lamawiki::Tokenbucket->new({'burst' => 3, 'period' => 1 * 3600}),
});

for my $n (0 .. $#{$spec}) {
    my $remote = '127.0.0.1';
    my $time0 = time;
    $wiki->sch->preset($wiki, $remote, $time0);
    my $got;
    $wiki->db->begin_work;
    for my $i (0 .. $n) {
        my($h, $m, $s) = @{$spec->[$i]};
        my $now = $time0 + $h * 3600 + $m * 60 + $s;
        $got = $wiki->sch->pass($wiki, $remote, $now);
    }
    $wiki->db->commit;
    my($h, $m, $s, $expected) = @{$spec->[$n]};
    ok $got && $expected || ! $got && ! $expected,
        sprintf 'after %02d:%02d:%02d', $h, $m, $s;
}

