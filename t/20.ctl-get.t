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
use Lamawikix::Testutil qw(ctl_get dbx_fixup_data make_titles_sources fakeyaml_loadfile);
use HTML::Tinysiz;

plan tests => 136;

my $srcname = File::Spec->catfile(qw[. t data find.yml]);
my $datadir = File::Spec->catdir(qw[. data]);
my $dbname = File::Spec->catfile(qw[. data test.db]);
my $viewdir = File::Spec->catdir(qw[. view ja]);
-d $datadir or mkdir $datadir;
-e $dbname and unlink $dbname;

my $data = fakeyaml_loadfile($srcname);
my($titles, $sources) = make_titles_sources($data, Lamawiki::Page->new);

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
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/)});
    my %headers = @{$res->[1]};

    is ref $res, 'ARRAY',
        'it should return the PSGI response.';
    is $res->[0], 303,
        'it should redirect for /.';
    is $headers{'Location'}, '/1',
        'its location should be /1 for /.';
    is_deeply $res->[2], [],
        'its body should be nothing for /.';
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => '/wiki.cgi', 'PATH_INFO' => q()});
    my %headers = @{$res->[1]};

    is $res->[0], 303,
        'it should redirect for /wiki.cgi.';
    is $headers{'Location'}, '/wiki.cgi/1',
        'its location should be /wiki.cgi/1 for /wiki.cgi.';
    is_deeply $res->[2], [],
        'its body should be nothing for /wiki.cgi.';
}

for my $x (['Top', 1], ['InterWikiName', 2], ['All', 3], ['Recent', 4], ['Hoge', 16]) {
    my($q, $id) = @{$x};
    my $res = ctl_get($ctl,
        {'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/), 'QUERY_STRING' => $q});
    my %headers = @{$res->[1]};

    is $res->[0], 303,
        "it should redirect for /?$q.";
    is $headers{'Location'}, "/$id",
        "its location should be /$id for /?$q.";
    is_deeply $res->[2], [],
        "its body should be nothing for /?$q.";
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/9999)});
    my %headers = @{$res->[1]};

    is ref $res, 'ARRAY',
        'it should return the PSGI response.';
    is $res->[0], 303,
        'it should redirect for /9999.';
    is $headers{'Location'}, '/1',
        'its location should be /1 for /9999.';
    is_deeply $res->[2], [],
        'its body should be nothing for /9999.';
}

for my $x (['Top', 1], ['InterWikiName', 2], ['All', 3], ['Recent', 4], ['Hoge', 16]) {
    my($q, $id) = @{$x};
    my $res = ctl_get($ctl,
        {'SCRIPT_NAME' => '/wiki.cgi', 'PATH_INFO' => q(/), 'QUERY_STRING' => $q});
    my %headers = @{$res->[1]};

    is $res->[0], 303,
        "it should redirect for /wiki.cgi/?$q.";
    is $headers{'Location'}, "/wiki.cgi/$id",
        "its location should be /wiki.cgi/$id for /wiki.cgi/?$q.";
    is_deeply $res->[2], [],
        "its body should be nothing for /wiki.cgi/?$q.";
}

{
    my $res = ctl_get($ctl,
        {'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/), 'QUERY_STRING' => 'Notyet'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /?Notyet.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /?Notyet.';
    ok defined $body && ! ref $body,
        'its body should be string for /?Notyet.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/?Notyet"])),
        'its body should have %a(href="/?Notyet")';
}

{
    my $res = ctl_get($ctl,
        {'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/), 'QUERY_STRING' => 'remote=alice'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /?remote=alice.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /?remote=alice.';
    ok defined $body && ! ref $body,
        'its body should be string for /?remote=alice.';

    my $alice_recent = [
        map { join q(/), q(), $_->id, $_->rev }
        sort { -($a->rev <=> $b->rev) }
        map { $_->new({%{$_}, 'source' => '', 'content' => ''}) }
        grep { $_->remote eq 'alice' }
        values %{$sources}];
    splice @{$alice_recent}, $wiki->config->{'recent.limit'};

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/?remote=alice"])),
        'its body should have %a(href="/?remote=alice")';
    is_deeply [map { $_->attr->{'href'} } $doc->getall(q(ul.sources a))],
              $alice_recent,
        'its body should have the links to alice recent posts.';
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/1'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /1.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /1.';
    ok defined $body && ! ref $body,
        'its body should be string for /1.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/1"])),
        'its body should have %a(href="/1") Top';
    ok defined $doc->get(q(.content a[href="/5"][title="TestPage"])),
        'its body should have %a(href="/5" title="TestPage")';
    ok defined $doc->get(q(.posted a[href="/1/1"])),
        'its body should have .posted %a(href="/1/1")';
    ok defined $doc->get(q(form[action="/1/history"])),
        'its body should have %form(action="/1/history")';
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/2'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /2.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /2.';
    ok defined $body && ! ref $body,
        'its body should be string for /2.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/2"])),
        'its body should have %a(href="/2") InterWikiName';
    ok defined $doc->get(q(.posted a[href="/2/2"])),
        'its body should have .posted %a(href="/2/2")';
    ok defined $doc->get(q(form[action="/2/history"])),
        'its body should have %form(action="/2/history")';
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/3'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /3.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /3.';
    ok defined $body && ! ref $body,
        'its body should be string for /3.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/3"])),
        'its body should have %a(href="/3") All';
    ok ! defined $doc->get(q(.posted a)),
        'its body should not have .posted %a';
    ok ! defined $doc->get(q(form[action="/3/history"])),
        'its body should not have %form(action="/3/history")';

    my $all_links = [
        map { q(/) . $_->id }
        sort { $a->title cmp $b->title }
        grep { $titles->{$_->id}->rev == $_->rev }
        values %{$sources}
    ];
    is_deeply [map { $_->attr->{'href'} } $doc->getall(q(ul.content-all a))],
              $all_links,
        'its body should have all links.';
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/4'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /4.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /4.';
    ok defined $body && ! ref $body,
        'its body should be string for /4.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/4"])),
        'its body should have %a(href="/4") Recent';
    ok ! defined $doc->get(q(.posted a)),
        'its body should not have .posted %a';
    ok ! defined $doc->get(q(form[action="/4/history"])),
        'its body should not have %form(action="/4/history")';

    my $recent_links = [
        map { q(/) . $_->id }
        sort { -($a->rev <=> $b->rev) }
        map { $_->new({%{$_}, 'source' => '', 'content' => ''}) }
        grep { $titles->{$_->id}->rev == $_->rev }
        values %{$sources}
    ];
    splice @{$recent_links}, $wiki->config->{'recent.limit'};
    is_deeply [map { $_->attr->{'href'} } $doc->getall(q(ul.content-recent a))],
              $recent_links,
        'its body should have recent links.';
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/5'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /5.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /5.';
    ok defined $body && ! ref $body,
        'its body should be string for /5.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/5"])),
        'its body should have %a(href="/5") TestPage';
    ok defined $doc->get(q(.content a[href="/6"][title="Foo"])),
        'its body should have %a(href="/6" title="Foo")';
    ok defined $doc->get(q(.content a[href="/7"][title="Bar"])),
        'its body should have %a(href="/7" title="Bar")';
    ok defined $doc->get(q(.posted a[href="/5/3"])),
        'its body should have .posted %a(href="/5/3")';
    ok defined $doc->get(q(form[action="/5/history"])),
        'its body should have %form(action="/5/history")';
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/6'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /6.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /6.';
    ok defined $body && ! ref $body,
        'its body should be string for /6.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/6"])),
        'its body should have %a(href="/6") Foo';
    ok 0 < (index $body, $titles->{6}->content),
        'its body should have content.';
    ok defined $doc->get(q(.posted a[href="/6/22"])),
        'its body should have .posted %a(href="/6/22")';
    ok defined $doc->get(q(form[action="/6/history"])),
        'its body should have %form(action="/6/history")';
}

{
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /7.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /7.';
    ok defined $body && ! ref $body,
        'its body should be string for /7.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/7"])),
        'its body should have %a(href="/7") Bar';
    ok 0 < (index $body, $titles->{7}->content),
        'its body should have content.';
    ok defined $doc->get(q(.posted a[href="/7/33"])),
        'its body should have .posted %a(href="/7/33")';
    ok defined $doc->get(q(form[action="/7/history"])),
        'its body should have %form(action="/7/history")';
}

{
    # {id: 7, title: Bar, history: [33, 26, 17, 10, 5]}
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7/history'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /7/history.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /7/history.';
    ok defined $body && ! ref $body,
        'its body should be string for /7/history.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/7"])),
        'its body should have %a(href="/7") Bar';
    ok ! defined $doc->get(q(.posted a)),
        'its body should have .posted %a';
    ok defined $doc->get(q(form[action="/7/history"])),
        'its body should have %form(action="/7/history")';

    is_deeply [map { $_->attr->{'href'} } $doc->getall(q(ul.history a))],
              [qw(/7/33 /?remote=alice
                  /7/26 /?remote=alice
                  /7/17 /?remote=alice
                  /7/10 /?remote=alice
                  /7/5  /?remote=alice)],
        'its body should have the links to /7/{33,26,17,10,5}.';
}

{
    # {id: 7, title: Bar, history: [33, 26, 17, 10, 5]}
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7/33'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /7/33.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /7/33.';
    ok defined $body && ! ref $body,
        'its body should be string for /7/33.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/7"])),
        'its body should have %a(href="/7") Bar';
    ok defined $doc->get(q(.posted a.self[href="/7/33"])),
        'its body should have %a.self(href="/7/33")';
    ok defined $doc->get(q(.posted a.prev[href="/7/26"])),
        'its body should have %a.prev(href="/7/26")';
    ok defined $doc->get(q(form[action="/7/history"])),
        'its body should have %form(action="/7/history")';
}

{
    # {id: 7, title: Bar, history: [33, 26, 17, 10, 5]}
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7/20'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'it should redirect for /7/20.';
    is $headers{'Location'}, '/7/17',
        'its location should be /7/17.';
    is_deeply $res->[2], [],
        'its body should be nothing for /7/17.';
}

{
    # {id: 7, title: Bar, history: [33, 26, 17, 10, 5]}
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7/17'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /7/17.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /7/17.';
    ok defined $body && ! ref $body,
        'its body should be string for /7/17.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/7"])),
        'its body should have %a(href="/7") Bar';
    ok defined $doc->get(q(.posted a.self[href="/7/17"])),
        'its body should have %a.self(href="/7/17")';
    ok defined $doc->get(q(.posted a.prev[href="/7/10"])),
        'its body should have %a.prev(href="/7/10")';
    ok defined $doc->get(q(form[action="/7/history"])),
        'its body should have %form(action="/7/history")';
}

{
    # {id: 7, title: Bar, history: [33, 26, 17, 10, 5]}
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7/9'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'it should redirect for /7/9.';
    is $headers{'Location'}, '/7/5',
        'its location should be /7/5.';
    is_deeply $res->[2], [],
        'its body should be nothing for /7/9.';
}

{
    # {id: 7, title: Bar, history: [33, 26, 17, 10, 5]}
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7/5'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'its status should be 200 Ok for /7/5.';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'its header should have test/html for /7/5.';
    ok defined $body && ! ref $body,
        'its body should be string for /7/5.';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get(q(h1 a[href="/7"])),
        'its body should have %a(href="/7") Bar';
    ok defined $doc->get(q(.posted a.self[href="/7/5"])),
        'its body should have %a.self(href="/7/5")';
    ok ! defined $doc->get(q(.posted a.prev)),
        'its body should not have %a.prev';
    ok defined $doc->get(q(form[action="/7/history"])),
        'its body should have %form(action="/7/history")';
}

{
    # {id: 7, title: Bar, history: [33, 26, 17, 10, 5]}
    my $res = ctl_get($ctl, {'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7/4'});
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'it should redirect for /7/4.';
    is $headers{'Location'}, '/7',
        'its location should be /7.';
    is_deeply $res->[2], [],
        'its body should be nothing for /7/4.';
}

