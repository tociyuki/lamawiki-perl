use strict;
use warnings;
use List::Util qw(first);
use File::Spec;
use Test::More;
use Lamawiki;
use Lamawiki::Sqlite;
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

plan tests => 99;

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
    'capability' => Lamawiki::Capability->new,
    'session' => Lamawiki::Cookie->new,
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

# update 6:5:Protect on 3:5:Protect by carol
{
    my $res = ctl_get($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => '/5',
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
    }, $now);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'GET /5 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'GET /5 => text/html';
    ok defined $body && ! ref $body,
        'GET /5 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('h1 a[href="/5"]'),
        'GET /5 => h1 %a(href="/5")';
    ok defined $doc->get('.posted a[href="/5/3"]'),
        'GET /5 => .posted %a(href="/5/3")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'GET /5 => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'GET /5 =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Protect"]'),
        'GET /5 =>   %input(name="q" value="Protect")/';
}

{
    my $res = ctl_post($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<'EOS', $now + 1);
--e9jae38ry
Content-Disposition: form-data; name="c"

e
--e9jae38ry
Content-Disposition: form-data; name="q"

Protect
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'POST {c:e, q:Protect} => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'POST {c:e, q:Protect} => text/html';
    ok defined $body && ! ref $body,
        'POST {c:e, q:Protect} => body';

    my $doc = HTML::Tinysiz->new($body);
    my $form = first(sub{ defined $_->get('input[name="c"][value="w"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'POST {c:e, q:Protect} => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="w"]'),
        'POST {c:e, q:Protect} =>   %input(name="c" value="w")/';
    ok defined $form->get('input[name="q"][value="Protect"]'),
        'POST {c:e, q:Protect} =>   %input(name="q" value="Protect")/';
    ok defined $form->get('input[name="r"][value="3"]'),
        'POST {c:e, q:Protect} =>   %input(name="r" value="3")/';
    ok defined $form->get('input[name="e"][value="cMhbbLZiSwJSB3npECi9vEczBEN7rRr1rDDa2FaEpRIjjP3gqkJyW9vFdOU93WCL1"]'),
        'POST {c:e, q:Protect} =>   %input(name="e" value="..")/';
    ok defined $form->get('textarea[name="t"]'),
        'POST {c:e, q:Protect} =>   %textarea(name="t")';
}

{
    my $res = ctl_post($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<'EOS', $now + 100);
--e9jae38ry
Content-Disposition: form-data; name="c"

w
--e9jae38ry
Content-Disposition: form-data; name="q"

Protect
--e9jae38ry
Content-Disposition: form-data; name="r"

3
--e9jae38ry
Content-Disposition: form-data; name="e"

cMhbbLZiSwJSB3npECi9vEczBEN7rRr1rDDa2FaEpRIjjP3gqkJyW9vFdOU93WCL1
--e9jae38ry
Content-Disposition: form-data; name="t"

# protect page

Hello, Test (alice).
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};

    is $res->[0], 303,
        'POST {c:w, q:Protect, r:3} => 303 Redirect';
    is $headers{'Location'}, '/5',
        'POST {c:w, q:Protect, r:3} => Location: /5';
    is_deeply $res->[2], [],
        'POST {c:w, q:Protect, r:3} => no body';
}

{
    my $res = ctl_get($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => '/5',
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
    }, $now + 110);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'GET /5 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'GET /5 => text/html';
    ok defined $body && ! ref $body,
        'GET /5 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('h1 a[href="/5"]'),
        'GET /5 => h1 %a(href="/5")';
    ok defined $doc->get('.posted a[href="/5/6"]'),
        'GET /5 => .posted %a(href="/5/6")';
}

# update 7:6:Private on 4:6:Private by carol
{
    my $res = ctl_get($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => '/6',
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
    }, $now + 120);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'GET /6 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'GET /6 => text/html';
    ok defined $body && ! ref $body,
        'GET /6 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('h1 a[href="/6"]'),
        'GET /6 => h1 %a(href="/6")';
    ok defined $doc->get('.posted a[href="/6/4"]'),
        'GET /6 => .posted %a(href="/6/4")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'GET /6 => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'GET /6 =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Private"]'),
        'GET /6 =>   %input(name="q" value="Private")/';
}

{
    my $res = ctl_post($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<'EOS', $now + 130);
--e9jae38ry
Content-Disposition: form-data; name="c"

e
--e9jae38ry
Content-Disposition: form-data; name="q"

Private
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'POST {c:e, q:Private} => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'POST {c:e, q:Private} => text/html';
    ok defined $body && ! ref $body,
        'POST {c:e, q:Private} => body';

    my $doc = HTML::Tinysiz->new($body);
    my $form = first(sub{ defined $_->get('input[name="c"][value="w"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'POST {c:e, q:Private} => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="w"]'),
        'POST {c:e, q:Private} =>   %input(name="c" value="w")/';
    ok defined $form->get('input[name="q"][value="Private"]'),
        'POST {c:e, q:Private} =>   %input(name="q" value="Private")/';
    ok defined $form->get('input[name="r"][value="4"]'),
        'POST {c:e, q:Private} =>   %input(name="r" value="4")/';
    ok defined $form->get('input[name="e"][value="cMhbbLZiSwJSB3npECi9vEczBEN7rRr1rDDa2FaEpRIjjP3gqkJyW9vFdOU93WCL1"]'),
        'POST {c:e, q:Private} =>   %input(name="e" value="..")/';
    ok defined $form->get('textarea[name="t"]'),
        'POST {c:e, q:Private} =>   %textarea(name="t")';
}

{
    my $res = ctl_post($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<'EOS', $now + 190);
--e9jae38ry
Content-Disposition: form-data; name="c"

w
--e9jae38ry
Content-Disposition: form-data; name="q"

Private
--e9jae38ry
Content-Disposition: form-data; name="r"

4
--e9jae38ry
Content-Disposition: form-data; name="e"

cMhbbLZiSwJSB3npECi9vEczBEN7rRr1rDDa2FaEpRIjjP3gqkJyW9vFdOU93WCL1
--e9jae38ry
Content-Disposition: form-data; name="t"

# private page

Hello, Test private (carol).
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};

    is $res->[0], 303,
        'POST {c:w, q:Private, r:4} => 303 Redirect';
    is $headers{'Location'}, '/6',
        'POST {c:w, q:Private, r:4} => Location: /6';
    is_deeply $res->[2], [],
        'POST {c:w, q:Private, r:4} => no body';
}

{
    my $res = ctl_get($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => '/6',
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
    }, $now + 200);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'GET /6 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'GET /6 => text/html';
    ok defined $body && ! ref $body,
        'GET /6 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('h1 a[href="/6"]'),
        'GET /6 => h1 %a(href="/6")';
    ok defined $doc->get('.posted a[href="/6/7"]'),
        'GET /6 => .posted %a(href="/6/7")';
}

# update 8:7:Public on 5:7:Public by carol
{
    my $res = ctl_get($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7',
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
    }, $now + 210);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'GET /7 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'GET /7 => text/html';
    ok defined $body && ! ref $body,
        'GET /7 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('h1 a[href="/7"]'),
        'GET /7 => h1 %a(href="/7")';
    ok defined $doc->get('.posted a[href="/7/5"]'),
        'GET /7 => .posted %a(href="/7/5")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'GET /7 => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'GET /7 =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Public"]'),
        'GET /7 =>   %input(name="q" value="Public")/';
}

{
    my $res = ctl_post($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<'EOS', $now + 220);
--e9jae38ry
Content-Disposition: form-data; name="c"

e
--e9jae38ry
Content-Disposition: form-data; name="q"

Public
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'POST {c:e, q:Public} => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'POST {c:e, q:Public} => text/html';
    ok defined $body && ! ref $body,
        'POST {c:e, q:Public} => body';

    my $doc = HTML::Tinysiz->new($body);
    my $form = first(sub{ defined $_->get('input[name="c"][value="w"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'POST {c:e, q:Public} => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="w"]'),
        'POST {c:e, q:Public} =>   %input(name="c" value="w")/';
    ok defined $form->get('input[name="q"][value="Public"]'),
        'POST {c:e, q:Public} =>   %input(name="q" value="Public")/';
    ok defined $form->get('input[name="r"][value="5"]'),
        'POST {c:e, q:Public} =>   %input(name="r" value="5")/';
    ok defined $form->get('input[name="e"][value="cMhbbLZiSwJSB3npECi9vEczBEN7rRr1rDDa2FaEpRIjjP3gqkJyW9vFdOU93WCL1"]'),
        'POST {c:e, q:Public} =>   %input(name="e" value="..")/';
    ok defined $form->get('textarea[name="t"]'),
        'POST {c:e, q:Public} =>   %textarea(name="t")';
}

{
    my $res = ctl_post($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<'EOS', $now + 300);
--e9jae38ry
Content-Disposition: form-data; name="c"

w
--e9jae38ry
Content-Disposition: form-data; name="q"

Public
--e9jae38ry
Content-Disposition: form-data; name="r"

5
--e9jae38ry
Content-Disposition: form-data; name="e"

cMhbbLZiSwJSB3npECi9vEczBEN7rRr1rDDa2FaEpRIjjP3gqkJyW9vFdOU93WCL1
--e9jae38ry
Content-Disposition: form-data; name="t"

# public page

Hello, Test public (carol).
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};

    is $res->[0], 303,
        'POST {c:w, q:Public, r:5} => 303 Redirect';
    is $headers{'Location'}, '/7',
        'POST {c:w, q:Public, r:5} => Location: /7';
    is_deeply $res->[2], [],
        'POST {c:w, q:Public, r:5} => no body';
}

{
    my $res = ctl_get($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => '/7',
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
    }, $now + 310);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'GET /7 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'GET /7 => text/html';
    ok defined $body && ! ref $body,
        'GET /7 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('h1 a[href="/7"]'),
        'GET /7 => h1 %a(href="/7")';
    ok defined $doc->get('.posted a[href="/7/8"]'),
        'GET /7 => .posted %a(href="/7/8")';
}

# insert 9:8:Foo on Foo by carol
{
    my $res = ctl_get($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => '/', 'QUERY_STRING' => 'Foo',
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
    }, $now + 320);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'GET /?Foo => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'GET /?Foo => text/html';
    ok defined $body && ! ref $body,
        'GET /?Foo => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('h1 a[href="/?Foo"]'),
        'GET /?Foo => h1 %a(href="/?Foo")';
    my $form = first(sub{ defined $_->get('input[name="c"][value="e"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'GET /?Foo => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="e"]'),
        'GET /?Foo =>   %input(name="c" value="e")/';
    ok defined $form->get('input[name="q"][value="Foo"]'),
        'GET /?Foo =>   %input(name="q" value="Foo")/';
}

{
    my $res = ctl_post($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<'EOS', $now + 330);
--e9jae38ry
Content-Disposition: form-data; name="c"

e
--e9jae38ry
Content-Disposition: form-data; name="q"

Foo
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'POST {c:e, q:Foo} => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'POST {c:e, q:Foo} => text/html';
    ok defined $body && ! ref $body,
        'POST {c:e, q:Foo} => body';

    my $doc = HTML::Tinysiz->new($body);
    my $form = first(sub{ defined $_->get('input[name="c"][value="w"]') },
                      $doc->getall('form[method="POST"][action="/"]'));
    ok defined $form,
        'POST {c:e, q:Foo} => %form(method="POST" action="/")';
    ok defined $form->get('input[name="c"][value="w"]'),
        'POST {c:e, q:Foo} =>   %input(name="c" value="w")/';
    ok defined $form->get('input[name="q"][value="Foo"]'),
        'POST {c:e, q:Foo} =>   %input(name="q" value="Foo")/';
    ok defined $form->get('input[name="r"][value="0"]'),
        'POST {c:e, q:Foo} =>   %input(name="r" value="0")/';
    ok defined $form->get('input[name="e"][value="cMhbbLZiSwJSB3npECi9vEczBEN7rRr1rDDa2FaEpRIjjP3gqkJyW9vFdOU93WCL1"]'),
        'POST {c:e, q:Foo} =>   %input(name="e" value="..")/';
    ok defined $form->get('textarea[name="t"]'),
        'POST {c:e, q:Foo} =>   %textarea(name="t")';
}

{
    my $res = ctl_post($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
        'CONTENT_TYPE' => 'multipart/form-data; boundary=e9jae38ry',
    }, <<'EOS', $now + 400);
--e9jae38ry
Content-Disposition: form-data; name="c"

w
--e9jae38ry
Content-Disposition: form-data; name="q"

Foo
--e9jae38ry
Content-Disposition: form-data; name="r"

0
--e9jae38ry
Content-Disposition: form-data; name="e"

cMhbbLZiSwJSB3npECi9vEczBEN7rRr1rDDa2FaEpRIjjP3gqkJyW9vFdOU93WCL1
--e9jae38ry
Content-Disposition: form-data; name="t"

# foo page

Hello, Test foo (carol).
--e9jae38ry--
EOS
    my %headers = @{$res->[1]};

    is $res->[0], 303,
        'POST {c:w, q:Foo, r:0} => 303 Redirect';
    is $headers{'Location'}, '/8',
        'POST {c:w, q:Foo, r:0} => Location: /8';
    is_deeply $res->[2], [],
        'POST {c:w, q:Foo, r:0} => no body';
}

{
    my $res = ctl_get($ctl, {
        'SCRIPT_NAME' => q(), 'PATH_INFO' => '/8',
        'HTTP_COOKIE' => 's=cM7JdZSBY5Y2iD0aAgRTTIxjgoBlul50h1wc53iXmcCl1DbW2pwKxlTYBezem5HfU',
    }, $now + 410);
    my %headers = @{$res->[1]};
    my $body = $res->[2][0];

    is $res->[0], 200,
        'GET /8 => 200 Ok';
    is $headers{'Content-Type'}, 'text/html; charset=utf-8',
        'GET /8 => text/html';
    ok defined $body && ! ref $body,
        'GET /8 => body';

    my $doc = HTML::Tinysiz->new($body);
    ok defined $doc->get('h1 a[href="/8"]'),
        'GET /8 => h1 %a(href="/8")';
    ok defined $doc->get('.posted a[href="/8/9"]'),
        'GET /8 => .posted %a(href="/8/9")';
}

