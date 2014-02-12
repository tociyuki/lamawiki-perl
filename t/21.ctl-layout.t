use strict;
use warnings;
use File::Spec;
use Test::More;
use Lamawiki;
use Lamawiki::Sqlite;
use Lamawiki::Page;
use Lamawiki::Interwiki;
use Lamawiki::Liq;
use Lamawiki::Layout;
use Lamawiki::Controller;
use lib qw(t/lib);
use Lamawikix::Testutil qw(ctl_get dbx_fixup_data fakeyaml_loadfile);
use HTML::Tinysiz;

plan tests => 45;

my $srcname = File::Spec->catfile(qw[. t data layout.yml]);
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
});

my $ctl = Lamawiki::Controller->new({
    'wiki' => $wiki,
    'view' => Lamawiki::Liq->new({'dir' => $viewdir}),
    'layout' => Lamawiki::Layout->new,
});

{
    # 3:5:ToPage ![][referer]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/5'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '3:5:ToPage body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    is_deeply [map { $_->attr->{'href'} } $doc->getall(q(.layout-index a))],
              [qw(/10 /7 /9 /8)],
        '![][referer] should has %a(href="{/10,/7,/9,/8}")';
}

{
    # 4:6:OhterPage ![][referer:ToPage]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/6'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '4:6:OhterPage body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    is_deeply [map { $_->attr->{'href'} } $doc->getall(q(.layout-index a))],
              [qw(/10 /7 /9 /8)],
        '![][referer] should has %a(href="{/10,/7,/9,/8}")';
}

{
    # 9:11:Parent ![][[nav]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/11'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '9:11:Parent body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('li.prev'),
        '![][[nav]] should have %li.prev';
    ok ! defined $doc->get('li.prev a[rel="prev"]'),
        '![][[nav]] should not have %a(rel="prev")';
    ok defined $doc->get('li.next a[rel="next"][href="/12"]'),
        '![][[nav]] should have %a(rel="next" href="/12") Child1';
    ok defined $doc->get('li.parent a[rel="parent"][href="/11"]'),
        '![][[nav]] should have %a(rel="parent" href="/11") Parent';
}

{
    # 10:12:Child1 ![][[nav:Parent]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/12'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '10:12:Child1 body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('li.prev'),
        '![][[nav:Parent]] should have %li.prev';
    ok ! defined $doc->get('li.prev a[rel="prev"]'),
        '![][[nav:Parent]] should not have %a(rel="prev")';
    ok defined $doc->get('li.next a[rel="next"][href="/13"]'),
        '![][[nav:Parent]] should have %a(rel="next" href="/13") Child2';
    ok defined $doc->get('li.parent a[rel="parent"][href="/11"]'),
        '![][[nav:Parent]] should have %a(rel="parent" href="/11") Parent';
}

{
    # 11:13:Child2 ![][[nav:Parent]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/13'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '11:13:Child2 body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('li.prev a[rel="prev"][href="/12"]'),
        '![][[nav:Parent]] should have %a(rel="prev" href="/12") Child1';
    ok defined $doc->get('li.next a[rel="next"][href="/14"]'),
        '![][[nav:Parent]] should have %a(rel="next" href="/14") Child3';
    ok defined $doc->get('li.parent a[rel="parent"][href="/11"]'),
        '![][[nav:Parent]] should have %a(rel="parent" href="/11") Parent';
}

{
    # 12:14:Child3 ![][[nav:Parent]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/14'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '12:14:Child3 body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('li.prev a[rel="prev"][href="/13"]'),
        '![][[nav:Parent]] should have %a(rel="prev" href="/13") Child2';
    ok defined $doc->get('li.next a[rel="next"][href="/15"]'),
        '![][[nav:Parent]] should have %a(rel="next" href="/15") Child4';
    ok defined $doc->get('li.parent a[rel="parent"][href="/11"]'),
        '![][[nav:Parent]] should have %a(rel="parent" href="/11") Parent';
}

{
    # 13:15:Child4 ![][[nav:Parent]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/15'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '13:15:Child4 body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('li.prev a[rel="prev"][href="/14"]'),
        '![][[nav:Parent]] should have %a(rel="prev" href="/14") Child3';
    ok defined $doc->get('li.next a[rel="next"][href="/16"]'),
        '![][[nav:Parent]] should have %a(rel="next" href="/16") Child5';
    ok defined $doc->get('li.parent a[rel="parent"][href="/11"]'),
        '![][[nav:Parent]] should have %a(rel="parent" href="/11") Parent';
}

{
    # 14:16:Child5 ![][[nav:Parent]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/16'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '14:16:Child5 body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('li.prev a[rel="prev"][href="/15"]'),
        '![][[nav:Parent]] should have %a(rel="prev" href="/15") Child4';
    ok defined $doc->get('li.next'),
        '![][[nav:Parent]] should have %li.prev';
    ok ! defined $doc->get('li.next a[rel="next"]'),
        '![][[nav:Parent]] should not have %a(rel="next")';
    ok defined $doc->get('li.parent a[rel="parent"][href="/11"]'),
        '![][[nav:Parent]] should have %a(rel="parent" href="/11") Parent';
}

{
    # 15:17:ListChild ![][[index:Child]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/17'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '15:17:ListChild body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('a[href="/12"]'),
        '![][[index:Child]] should have %a(href="/12") Child1';
    ok defined $doc->get('a[href="/13"]'),
        '![][[index:Child]] should have %a(href="/13") Child2';
    ok defined $doc->get('a[href="/14"]'),
        '![][[index:Child]] should have %a(href="/14") Child3';
    ok defined $doc->get('a[href="/15"]'),
        '![][[index:Child]] should have %a(href="/15") Child4';
    ok defined $doc->get('a[href="/16"]'),
        '![][[index:Child]] should have %a(href="/16") Child5';
}

{
    # 16:18:PageToc ![][[toc:PageSect]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/18'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '16:18:PageToc body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    is_deeply [map { $_->attr->{'href'} } $doc->getall('.content a')],
              ['/19#r17Heading1-1', '/19#r17Heading1-2'],
        '![][[toc:PageSect]] should have %a(href="/19#r17Heading1-{1,2}")';
}

{
    # 17:19:PageSect ![Table of Content][[toc]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/19'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '16:18:PageToc body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    is_deeply [map { $_->attr->{'href'} } $doc->getall('.content a')],
              ['#r17Heading1-1', '#r17Heading1-2'],
        '![][[toc:PageSect]] should have %a(href="#r17Heading1-{1,2}")';
}

{
    # 18:20:Frame1 ![][[include:Frame2]] ![][[include:Frame4]]
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/20'});
    my $body = $res->[2][0];

    ok $res->[0] == 200 && defined $body && ! ref $body,
        '16:18:PageToc body should be string.';
    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('a[href="/22"]'),
        '![][[include:..] should have %a(href="/22") Frame3';
    ok defined $doc->get('a[href="/23"]'),
        '![][[include:..] should have %a(href="/23") Frame4';
    ok defined $doc->get('a[href="/24"]'),
        '![][[include:..] should have %a(href="/24") Frame5';
}

