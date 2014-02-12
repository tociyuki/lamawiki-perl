use strict;
use warnings;
use Test::More tests => 483;
use Lamawiki::Strftime qw(strftime);
use Lamawiki;

BEGIN { use_ok 'Lamawiki::Page' }

can_ok 'Lamawiki::Page', qw(
    new empty rev posted remote id title summary source output content rel
);

{
    my $it = Lamawiki::Page->new({
        'rev' => 6,
        'posted' => strftime('%s', '2006-05-04 03:02:01'),
        'remote' => '127.0.0.1',
        'id' => 2,
        'title' => 'title varchar',
        'summary' => 'summary varchar',
        'source' => 'body text',
        'content' => "\n<p>body text</p>\n",
        'rel' => [Lamawiki::Page->new({'rev' => 24, 'id' => 10, 'title' => 'Goo'}),
                  Lamawiki::Page->new({'rev' => 26, 'id' => 16, 'title' => 'Muu'}),
                  Lamawiki::Page->new({'rev' => 28, 'id' => 17, 'title' => 'Ngg'})],
    });

    ok ref $it && $it->isa('Lamawiki::Page'),
        'its new should create an instance of it.';
    is $it->rev, 6,
        'its new should inject a value of attribute `rev`.';
    is $it->posted, strftime('%s', '2006-05-04 03:02:01'),
        'its new should inject a value of attribute `posted`.';
    is $it->remote, '127.0.0.1',
        'its new should inject a value of attribute `remote`.';
    is $it->id, 2,
        'its new should inject a value of attribute `id`.';
    is $it->title, 'title varchar',
        'its new should inject a value of attribute `title`.';
    is $it->summary, 'summary varchar',
        'its new should inject a value of attribute `summary`.';
    is $it->source, 'body text',
        'its new should inject a value of attribute `source`.';
    is $it->content, "\n<p>body text</p>\n",
        'its new should inject a value of attribute `content`.';
    is_deeply $it->rel,
        [Lamawiki::Page->new({'rev' => 24, 'id' => 10, 'title' => 'Goo'}),
         Lamawiki::Page->new({'rev' => 26, 'id' => 16, 'title' => 'Muu'}),
         Lamawiki::Page->new({'rev' => 28, 'id' => 17, 'title' => 'Ngg'})],
        'its new should inject a value of attribute `rel`.';

    is $it->rev(7), 7,
        'its rev should replace an another value.';
    is $it->rev, 7,
        'its rev should keep a replaced value.';

    is $it->posted(strftime('%s', '2007-06-05 04:03:02')),
        strftime('%s', '2007-06-05 04:03:02'),
        'its posted should replace an another value.';
    is $it->posted, strftime('%s', '2007-06-05 04:03:02'),
        'its posted should keep a replaced value.';

    is $it->remote('128.1.1.2'), '128.1.1.2',
        'its remote should replace an another value.';
    is $it->remote, '128.1.1.2',
        'its remote should keep a replaced value.';

    is $it->id(3), 3,
        'its id should replace an another value.';
    is $it->id, 3,
        'its id should keep a replaced value.';

    is $it->title('foo'), 'foo',
        'its title should replace an another value.';
    is $it->title, 'foo',
        'its title should keep a replaced value.';

    is $it->summary('foo summary'), 'foo summary',
        'its summary should replace an another value.';
    is $it->summary, 'foo summary',
        'its summary should keep a replaced value.';

    is $it->source('bar'), 'bar',
        'its source should replace an another value.';
    is $it->source, 'bar',
        'its source should keep a replaced value.';

    is $it->content('foo content'), 'foo content',
        'its content should set a value.';
    is $it->content, 'foo content',
        'its content should keep a last set value.';

    is $it->output('foo output'), 'foo output',
        'its content should set a value.';
    is $it->output, 'foo output',
        'its content should keep a last set value.';
}

{
    my $it = Lamawiki::Page->empty('test title');

    ok ref $it && $it->isa('Lamawiki::Page'),
        'its empty should create an instance of it.';
    is $it->rev, 0,
        'its empty should set 0 into attribute `rev`.';
    ok ! defined $it->posted,
        'its empty should set undef into attribute `posted`.';
    ok ! defined $it->remote,
        'its empty should set undef attribute `remote`.';
    ok ! defined $it->id,
        'its empty should set undef into attribute `id`.';
    is $it->title, 'test title',
        'its empty should inject a value of attribute `title`.';
    is $it->summary, q(),
        'its empty should set empty string attribute `summary`.';
    is $it->source, q(),
        'its empty should set empty string attribute `source`.';
}

{
    my $it = Lamawiki::Page->empty('test title', 6);

    ok ref $it && $it->isa('Lamawiki::Page'),
        'its empty should create an instance of it.';
    is $it->rev, 0,
        'its empty should set 0 into attribute `rev`.';
    ok ! defined $it->posted,
        'its empty should set undef into attribute `posted`.';
    ok ! defined $it->remote,
        'its empty should set undef attribute `remote`.';
    is $it->id, 6,
        'its empty should inject a value of attribute `id`.';
    is $it->title, 'test title',
        'its empty should inject a value of attribute `title`.';
    is $it->summary, q(),
        'its empty should set empty string attribute `summary`.';
    is $it->source, q(),
        'its empty should set empty string attribute `source`.';
}

{
    my $it = Lamawiki::Page->new;

    for my $r (map {chr} 0x20 .. 0x7e) {
        if ($r =~ m/\A[1-9]\z/msx) {
            ok $it->is_id($r),
                qq('$r' should be an id.);
        }
        else {
            ok ! $it->is_id($r),
                qq('$r' should not be an id.);
        }
    }
    for my $r ('0' .. '9') {
        ok ! $it->is_id("0$r"),
            qq('0$r' should not be an id.);
    }
    for my $h ('1' .. '9') {
        for my $r ('0' .. '9') {
            ok $it->is_id("$h$r"),
                qq('$h$r' should be an id.);
        }
    }

    ok     $it->is_id('100000000'),
        q(100000000 should be an id.);
    ok     $it->is_id('999999999'),
        q(999999999 should be an id.);
    ok  ! $it->is_id('1000000000'),
       q(1000000000 should not be an id.);
    ok ! $it->is_id('10000000000'),
       q(1000000000 should not be an id.);
}

{
    my $it = Lamawiki::Page->new;

    for my $r (map {chr} 0x20 .. 0x7e) {
        if ($r =~ m/\A[0-9]\z/msx) {
            ok $it->is_rev($r),
                qq('$r' should be a revision.);
        }
        else {
            ok ! $it->is_rev($r),
                qq('$r' should not be a revision.);
        }
    }
    for my $r ('0' .. '9') {
        ok ! $it->is_rev("0$r"),
            qq('0$r' should not be a revision.);
    }
    for my $h ('1' .. '9') {
        for my $r ('0' .. '9') {
            ok $it->is_rev("$h$r"),
                qq('$h$r' should be a revision.);
        }
    }

    is    $it->MAXREV, '999999999',
        'MAXREV should be 999999999.';

    ok     $it->is_rev('100000000'),
        q(100000000 should be a revision.);
    ok     $it->is_rev('999999999'),
        q(999999999 should be a revision.);
    ok  ! $it->is_rev('1000000000'),
       q(1000000000 should not be a revision.);
    ok ! $it->is_rev('10000000000'),
       q(1000000000 should not be a revision.);
}

{
    my $it = Lamawiki::Page->new;

    ok ! $it->is_title(undef),
        'undef should not be a title.';

    ok ! $it->is_title(q()),
        'empty string should not be a title.';

    ok ! $it->is_title('x' x 512),
        'long string should not be a title.';

    for my $q (
        'FrontPage', 'All', 'RecentChanges',
        'front page', 'all', 'recent changes',
        'http', '0123',
        'a/b', 'a:b', 'a b', 'a:b/c', 'a b:c/d',
        q(Mr. foo and Mrs. bar), q(A's something),
        q(!"$%&'()*+,-./:;=^_`~),
        q(!"$%&'()*+,-./:;=^_`~ !"$%&'()*+,-./:;=^_`~),,
    ) {
        ok $it->is_title($q),
            qq('$q' should be a title.);
    }
    for my $q (split //, q( #?@\\|[]{}<>)) {
        ok ! $it->is_title("a$q"),
            qq('a$q' should not include other ASCII7 space or punctuations.);        
    }
}

{
    package Mock::Db;
    sub call { return [] }
}

{
    my $wiki = Lamawiki->new({
        'db' => (bless {}, 'Mock::Db'),
        'config' => {
            'default.title' => 'Top',
            'all.title' => 'All',
            'recent.title' => 'Recent',
        },
    });

    my $it = Lamawiki::Page->new;

    ok $it->see_title($wiki, $wiki->default_title)->can('title'),
        'its see_title should make an instance.';

    is $it->see_title($wiki, $wiki->default_title)->title, $wiki->default_title,
        'its see_title should make the default title page.';
    is $it->see_title($wiki)->title, $wiki->default_title,
        'its see_title should make the default title page as defaults.';
    is $it->see_title($wiki, '? invalid #')->title, $wiki->default_title,
        'its see_title should make the default title page for invalids.';

    is $it->see_title($wiki, $wiki->all_title)->title, $wiki->all_title,
        'its see_title should make the All page.';
    is $it->see_title($wiki, $wiki->recent_title)->title, $wiki->recent_title,
        'its see_title should make the RecentChanges page.';

}

