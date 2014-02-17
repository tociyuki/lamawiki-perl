use strict;
use warnings;
use File::Spec;
use Test::More;
use Lamawiki;
use Lamawiki::Sqlite;
use Lamawiki::Page;
use Lamawiki::Interwiki;
use Lamawiki::Liq;
use Lamawiki::Converter;
use Lamawiki::Layout;
use Lamawiki::Controller;
use lib qw(t/lib);
use Lamawikix::Testutil qw(ctl_get dbx_fixup_data fakeyaml_loadfile);
use HTML::Tinysiz;

plan tests => 8;

my $srcname = File::Spec->catfile(qw[. t data interwiki.yml]);
my $datadir = File::Spec->catdir(qw[. data]);
my $dbname = File::Spec->catfile(qw[. data test.db]);
my $viewdir = File::Spec->catdir(qw[. view ja]);
-d $datadir or mkdir $datadir;
-e $dbname and unlink $dbname;

my $data = fakeyaml_loadfile($srcname);

my $wiki = Lamawiki->new({
    'config' => {
        'default.title' => 'Top',
        'interwiki.title' => 'InterWikiName',
        'all.title' => 'All',
        'recent.title' => 'Recent',
        'recent.limit' => 20,
    },
    'db' => Lamawiki::Sqlite->connect("dbi:SQLite:dbname=$dbname", q(), q(), sub{
        my($db) = @_;
        $db->fixup($db->module->{'create_table'});
        dbx_fixup_data($db, $data);
    }),
    'page' => Lamawiki::Page->new,
    'interwiki' => Lamawiki::Interwiki->new,
    'converter' => Lamawiki::Converter->new,
});

{
    my $wiki1 = $wiki->reload_interwiki;

    ok ref $wiki1 && $wiki1->isa('Lamawiki'),
        'it should be a wiki.';

    ok ref $wiki1->interwiki && $wiki1->interwiki->isa('Lamawiki::Interwiki'),
        'its interwiki should be a interwiki.';

    ok ref $wiki1->interwiki->server,
        'its interwiki server should be a HashRef.';

    is_deeply $wiki1->interwiki->server, {
        'plain' => 'http://www.example.net/wiki?',
        'default' => 'http://www.example.net/wiki?title=$1&amp;command=browse',
        'bareamp' => 'http://www.example.net/wiki?title=$1&command=browse',
        'utf8' => 'http://www.example.net/wiki?$(1:utf8)',
        'euc' => 'http://www.example.net/wiki?$(1:euc)',
        'jis' => 'http://www.example.net/wiki?$(1:jis)',
        'sjis' => 'http://www.example.net/wiki?$(1:sjis)',
    }, 'it should reload page source.';
}

{
    my $ctl = Lamawiki::Controller->new({
        'wiki' => $wiki,
        'view' => Lamawiki::Liq->new({'dir' => $viewdir}),
        'layout' => Lamawiki::Layout->new,
    });
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => '/test', 'PATH_INFO' => '/5'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /test/5.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /test/5.';
    ok defined $body && ! ref $body,
        'its body should be string for /test/5.';

    my $doc = HTML::Tinysiz->new($body);
    is_deeply [map { $_->attr->{'href'} } $doc->getall('.content a')],
        [qw(/test/6
            http://www.example.net/wiki?%E6%8C%AF%E8%88%9E
            http://www.example.net/wiki?title=%E6%8C%AF%E8%88%9E&amp;command=browse
            http://www.example.net/wiki?%E6%8C%AF%E8%88%9E
            http://www.example.net/wiki?%BF%B6%C9%F1
            http://www.example.net/wiki?%1B%24B%3F6Iq%1B%28B
            http://www.example.net/wiki?%90U%95%91 )],
        'its content should has interwiki resolved links.';
}

