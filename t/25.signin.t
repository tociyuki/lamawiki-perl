use strict;
use warnings;
use List::Util qw(first);
use File::Spec;
use Test::More;
use Lamawiki;
use Lamawiki::Sqlite;
use Lamawiki::Htpasswd;
use Lamawiki::Capability;
use Lamawiki::Page;
use Lamawiki::Cookie;
use Lamawiki::Interwiki;
use Lamawiki::Liq;
use Lamawiki::Layout;
use Lamawiki::Converter;
use Lamawiki::Controller;
use Lamawiki::Strftime qw(strftime);
use lib qw(t/lib);
use Lamawikix::Testutil qw(ctl_get ctl_post dbx_fixup_data fakeyaml_loadfile);
use HTML::Tinysiz;

plan tests => 82;

my($alice_pass, $carol_pass) = ('aEdgakjt9kjer', 'i3.egw-teEKxPb8');
my $htpasswdfile = File::Spec->catfile(qw[. t data htpasswd]);
my $srcname = File::Spec->catfile(qw[. t data post.yml]);
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
        'role' => {'carol' => 'master'},
        'anonymous.edit' => 0,
        'domain' => [
            'InterWikiName' => 'private',
            'Private' => 'private',
            'Protect' => 'protect',
        ],
        'link_ok' => [],
        'maxpost' => 64 * 1024,
    },
    'db' => Lamawiki::Sqlite->connect("dbi:SQLite:dbname=$dbname", q(), q(), sub{
        my($db) = @_;
        $db->fixup($db->module->{'create_table'});
        dbx_fixup_data($db, $data);
    }),
    'auth' => Lamawiki::Htpasswd->new({'path' => $htpasswdfile}),
    'capability' => Lamawiki::Capability->new,
    'session' => Lamawiki::Cookie->new({'lifetime' => 12*3600}), # seconds
    'page' => Lamawiki::Page->new,
    'interwiki' => Lamawiki::Interwiki->new,
    'converter' => Lamawiki::Converter->new,
});

my $ctl = Lamawiki::Controller->new({
    'wiki' => $wiki,
    'view' => Lamawiki::Liq->new({'dir' => $viewdir}),
    'layout' => Lamawiki::Layout->new,
});

my $now = strftime('%s', '2014-01-02 08:01:00');

# /signin active only when $wiki->auth && $wiki->session
{
    my $ctl1 = $ctl->new({
        %{$ctl}, 'wiki' => $wiki->new({%{$wiki}, 'auth' => undef, 'session' => undef}),
    });

    my $res = ctl_get($ctl1, {'PATH_INFO' => '/signin'}, $now);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        '! auth || ! session GET /signin => 303 Redirect';
    is $headers{'Location'}, '/1',
        '! auth || ! session GET /signin => Location: /1';
}

{
    my $ctl1 = $ctl->new({
        %{$ctl}, 'wiki' => $wiki->new({%{$wiki}, 'auth' => undef}),
    });

    my $res = ctl_get($ctl1, {'PATH_INFO' => '/signin'}, $now);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        '! auth GET /signin => 303 Redirect';
    is $headers{'Location'}, '/1',
        '! auth GET /signin => Location: /1';
}

{
    my $ctl1 = $ctl->new({
        %{$ctl}, 'wiki' => $wiki->new({%{$wiki}, 'session' => undef}),
    });

    my $res = ctl_get($ctl1, {'PATH_INFO' => '/signin'}, $now);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        '! session GET /signin => 303 Redirect';
    is $headers{'Location'}, '/1',
        '! session GET /signin => Location: /1';
}

# alice user
my $alice_sesskey;

{
    my $res = ctl_get($ctl, {'PATH_INFO' => '/signin'}, $now);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'alice should GET /signin => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'alice should GET /signin => text/html';
    ok defined $body && ! ref $body,
        'alice should GET /signin => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('form[action="/signin"]'),
        'alice should GET /signin => %form(action="/signin")';
    ok defined $doc->get('form[action="/signin"] input[name="name"]'),
        'alice should GET /signin => %input(name="name")';
    ok defined $doc->get('form[action="/signin"] input[name="password"]'),
        'alice should GET /signin => %input(name="password")';
}

{
    my $res = ctl_post($ctl, {
        'PATH_INFO' => '/signin',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<"EOS", $now + 10);
--e9jae38ry
Content-Disposition: form-data; name="name"

alice
--e9jae38ry
Content-Disposition: form-data; name="password"

$alice_pass
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'alice should POST /signin {name:alice} => 303 Redirect';
    is $headers{'Location'}, '/1',
        'alice should POST /signin {name:alice} => Location: /1';
    ok defined $headers{'Set-Cookie'},
        'alice should POST /signin {name:alice} => Set-Cookie';
    like $headers{'Set-Cookie'}, qr/\As=[^;]/msx,
        'alice should POST /signin {name:alice} => Set-Cookie: s=...';
    $alice_sesskey = $headers{'Set-Cookie'};
    is_deeply $res->[2], [],
        'alice should POST {c:w, q:Top, r:0} => no body';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/1',
        'HTTP_COOKIE' => $alice_sesskey,
    }, $now + 20);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'alice should GET /1 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'alice should GET /1 => text/html';
    ok defined $body && ! ref $body,
        'alice should GET /1 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('a[href="/signout"]'),
        'alice should GET /1 => %a(href="/signout")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'alice should GET /1 => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'alice should GET /1 =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Top"]'),
        'alice should GET /1 =>   %input(name="q" value="Top")/';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/5',
        'HTTP_COOKIE' => $alice_sesskey,
    }, $now + 20);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'alice should GET /5 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'alice should GET /5 => text/html';
    ok defined $body && ! ref $body,
        'alice should GET /5 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('a[href="/signout"]'),
        'alice should GET /5 => %a(href="/signout")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'alice should GET /5 => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'alice should GET /5 =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Protect"]'),
        'alice should GET /5 =>   %input(name="q" value="Protect")/';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/6',
        'HTTP_COOKIE' => $alice_sesskey,
    }, $now + 20);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'alice should GET /6 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'alice should GET /6 => text/html';
    ok defined $body && ! ref $body,
        'alice should GET /6 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('a[href="/signout"]'),
        'alice should GET /6 => %a(href="/signout")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok ! defined $form,
        'alice should GET /6 => ! %form(method="POST" action="/")';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/signin',
        'HTTP_COOKIE' => $alice_sesskey,
    }, $now + 30);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'alice should GET /signin => 303 Redirect';
    is $headers{'Location'}, '/1',
        'alice should GET /signin => Location: /1';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/signout',
        'HTTP_COOKIE' => $alice_sesskey,
    }, $now + 40);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'alice should GET /signout => 303 Redirect';
    is $headers{'Location'}, '/1',
        'alice should GET /signout => Location: /1';
    ok defined $headers{'Set-Cookie'},
        'alice should GET /signout => Set-Cookie';
    like $headers{'Set-Cookie'}, qr/\As=;/msx,
        'alice should GET /signout {name:alice} => Set-Cookie: s=;';
    is_deeply $res->[2], [],
        'alice should GET /signout => no body';

    $alice_sesskey = undef;
}

# carol master
my $carol_sesskey;

{
    my $res = ctl_get($ctl, {'PATH_INFO' => '/signin'}, $now + 50);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'carol should GET /signin => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'carol should GET /signin => text/html';
    ok defined $body && ! ref $body,
        'carol should GET /signin => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('form[action="/signin"]'),
        'carol should GET /signin => %form(action="/signin")';
    ok defined $doc->get('form[action="/signin"] input[name="name"]'),
        'carol should GET /signin => %input(name="name")';
    ok defined $doc->get('form[action="/signin"] input[name="password"]'),
        'carol should GET /signin => %input(name="password")';
}

{
    my $res = ctl_post($ctl, {
        'PATH_INFO' => '/signin',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<"EOS", $now + 60);
--e9jae38ry
Content-Disposition: form-data; name="name"

carol
--e9jae38ry
Content-Disposition: form-data; name="password"

$carol_pass
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'carol should POST /signin {name:carol} => 303 Redirect';
    is $headers{'Location'}, '/1',
        'carol should POST /signin {name:carol} => Location: /1';
    ok defined $headers{'Set-Cookie'},
        'carol should POST /signin {name:carol} => Set-Cookie';
    like $headers{'Set-Cookie'}, qr/\As=[^;]/msx,
        'carol should POST /signin {name:carol} => Set-Cookie: s=...';
    $carol_sesskey = $headers{'Set-Cookie'};
    is_deeply $res->[2], [],
        'carol should POST {c:w, q:Top, r:0} => no body';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/1',
        'HTTP_COOKIE' => $carol_sesskey,
    }, $now + 70);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'carol should GET /1 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'carol should GET /1 => text/html';
    ok defined $body && ! ref $body,
        'carol should GET /1 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('a[href="/signout"]'),
        'carol should GET /1 => %a(href="/signout")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'carol should GET /1 => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'carol should GET /1 =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Top"]'),
        'carol should GET /1 =>   %input(name="q" value="Top")/';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/5',
        'HTTP_COOKIE' => $carol_sesskey,
    }, $now + 80);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'carol should GET /5 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'carol should GET /5 => text/html';
    ok defined $body && ! ref $body,
        'carol should GET /5 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('a[href="/signout"]'),
        'carol should GET /5 => %a(href="/signout")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'carol should GET /5 => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'carol should GET /5 =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Protect"]'),
        'carol should GET /5 =>   %input(name="q" value="Protect")/';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/6',
        'HTTP_COOKIE' => $carol_sesskey,
    }, $now + 90);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'carol should GET /6 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'carol should GET /6 => text/html';
    ok defined $body && ! ref $body,
        'carol should GET /6 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('a[href="/signout"]'),
        'carol should GET /6 => %a(href="/signout")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'carol should GET /6 => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'carol should GET /6 =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Private"]'),
        'carol should GET /6 =>   %input(name="q" value="Private")/';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/signin',
        'HTTP_COOKIE' => $carol_sesskey,
    }, $now + 100);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'carol should GET /signin => 303 Redirect';
    is $headers{'Location'}, '/1',
        'carol should GET /signin => Location: /1';
}

{
    my $res = ctl_get($ctl, {
        'PATH_INFO' => '/signout',
        'HTTP_COOKIE' => $carol_sesskey,
    }, $now + 110);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 303,
        'carol should GET /signout => 303 Redirect';
    is $headers{'Location'}, '/1',
        'carol should GET /signout => Location: /1';
    ok defined $headers{'Set-Cookie'},
        'carol should GET /signout => Set-Cookie';
    like $headers{'Set-Cookie'}, qr/\As=;/msx,
        'carol should GET /signout {name:carol} => Set-Cookie: s=;';
    is_deeply $res->[2], [],
        'carol should GET /signout => no body';

    $carol_sesskey = undef;
}

