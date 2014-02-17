use strict;
use warnings;
use File::Spec;
use Test::More;
use Lamawiki;
use Lamawiki::Sqlite;
use Lamawiki::Capability;
use Lamawiki::Page;
use Lamawiki::Cookie;

plan tests => 94;

my $datadir = File::Spec->catdir(qw[. data]);
my $dbname = File::Spec->catfile(qw[. data test.db]);
-d $datadir or mkdir $datadir;
-e $dbname and unlink $dbname;

{
    package Mock::Converter;
    sub convert {
        my($self, $page) = @_;
        return $page->new({%{$page},
            'summary' => $self->{'.summary'},
            'content' => $self->{'.content'},
            'rel' => $self->{'.rel'},
        });
    }
}

my $wiki0 = Lamawiki->new({
    'config' => {
        'default.title' => 'Top',
        'interwiki.title' => 'InterWikiName',
        'all.title' => 'All',
        'recent.title' => 'Recent',
        'recent.limit' => 20,
        'role' => {'carol' => 'master'},
        'domain' => ['InterWikiName' => 'private'],
        'link_ok' => [],
    },
    'db' => Lamawiki::Sqlite->connect("dbi:SQLite:dbname=$dbname", q(), q(), sub{
        my($db) = @_;
        $db->fixup($db->module->{'create_table'});
        for my $q (qw[Top InterWikiName All Recent]) {
            $db->call('titles.insert', {'title' => $q});
        }
    }),
    'capability' => Lamawiki::Capability->new,
    'converter' => (bless {}, 'Mock::Converter'),
    'page' => Lamawiki::Page->new,
});

my $post0 = $wiki0->now - 1000;

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => undef});

    ok ! defined $it,
        'it should fail to undefined id.';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 0});

    ok ! defined $it,
        'it should fail to illegal id 0.';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 1000000000});

    ok ! defined $it,
        'it should fail to illegal id 1000000000.';
}

{
    my $it = $wiki0->page->find($wiki0, 'title', {'title' => undef});

    ok ! defined $it,
        'it should fail to undefined title.';
}

{
    my $it = $wiki0->page->find($wiki0, 'title', {'title' => '?<illegal>#title'});

    ok ! defined $it,
        'it should fail to illegal title.';
}

{
    my $it = $wiki0->page->find($wiki0, 'title', {'title' => 'Page1'});

    ok ref $it && $it->{'page'}->can('title'),
        'its page should find *:*:Page1.';

    is $it->{'page'}->rev, 0,
        'its rev should be zero.';

    is $it->{'page'}->title, 'Page1',
        'its title should be Page1.';

    is $it->{'page'}->source, q(),
        'its source should be empty.';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 a',
            '.content' => "\n<p>test page1 rev1.</p>\n",
            '.rel' => [],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page1',
        'rev' => 0,
        'posted' => $post0 + 10,
        'remote' => '127.0.0.1',
        'source' => 'test page1 rev1.',
    });

    ok ref $it && exists $it->{'page'} && ! exists $it->{'orig'},
        'it should save 1:5:Page1.';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 5});

    ok ref $it && $it->{'page'}->can('id'),
        'its page should find title 1:5:Page1.';

    is $it->{'page'}->rev, 1,
        'its rev should be 1.';

    is $it->{'page'}->id, 5,
        'its id should be 5.';

    is $it->{'page'}->title, 'Page1',
        'its title should be Page1.';

    is $it->{'page'}->posted, $post0 + 10,
        'its posted should be post10 + 10.';

    is $it->{'page'}->remote, 'alice',
        'its remote should be "alice".';

    is $it->{'page'}->summary, 'test page1 a',
        'its source should be "test page1 a"';

    is $it->{'page'}->content, "\n<p>test page1 rev1.</p>\n",
        'its content should be "<p>test page1 rev1.</p>"';

    is_deeply $it->{'page'}->rel, [],
        'its rel should be [].';

    is $it->{'page'}->source, 'test page1 rev1.',
        'its source should be "test page1 rev1."';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page1',
        'rev' => 1,
        'posted' => $post0 + 20,
        'remote' => '127.0.0.1',
        'source' => 'test page1 rev2.',
    });

    ok ref $it && exists $it->{'page'} && ! exists $it->{'orig'},
        'it should save 2:5:Page1.';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 5});

    ok ref $it && $it->{'page'}->can('id'),
        'its page should find page 2:5:Page1.';

    is $it->{'page'}->rev, 2,
        'its rev should be 2.';

    is $it->{'page'}->id, 5,
        'its id should be 5.';

    is $it->{'page'}->title, 'Page1',
        'its title should be Page1.';

    is $it->{'page'}->posted, $post0 + 20,
        'its posted should be post10 + 20.';

    is $it->{'page'}->remote, 'alice',
        'its remote should be "alice".';

    is $it->{'page'}->summary, 'test page1 b',
        'its source should be "test page1 b"';

    is $it->{'page'}->content, "\n<p>test page1 rev2.</p>\n",
        'its content should be "<p>test page1 rev2.</p>"';

    is_deeply $it->{'page'}->rel,
        [$wiki0->page->new({'id' => 6, 'rev' => 0, 'title' => 'Page2'}),
         $wiki0->page->new({'id' => 7, 'rev' => 0, 'title' => 'Page3'})],
        'its rel should be [0:6:Page2, 0:7:Page3].';

    is $it->{'page'}->source, 'test page1 rev2.',
        'its source should be "test page1 rev2."';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'All',
        'rev' => 0,
        'posted' => $post0 + 30,
        'remote' => '127.0.0.1',
        'source' => 'test All rev1.',
    });

    ok ! defined $it,
        'it should not save readonly All.';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Recent',
        'rev' => 0,
        'posted' => $post0 + 30,
        'remote' => '127.0.0.1',
        'source' => 'test Recent rev1.',
    });

    ok ! defined $it,
        'it should not save readonly Recent.';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => '?illegal#title',
        'rev' => 0,
        'posted' => $post0 + 30,
        'remote' => '127.0.0.1',
        'source' => 'test Recent rev1.',
    });

    ok ! defined $it,
        'it should not save bad title.';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page1',
        'rev' => -1,
        'posted' => $post0 + 30,
        'remote' => '127.0.0.1',
        'source' => 'test Recent rev -1.',
    });

    ok ! defined $it,
        'it should not save bad rev -1 on 2:5:Page1.';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page1',
        'rev' => 4,
        'posted' => $post0 + 30,
        'remote' => '127.0.0.1',
        'source' => 'test Recent rev -1.',
    });

    ok ! defined $it,
        'it should not save bad rev 4 on 2:5:Page1.';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page1',
        'rev' => 2,
        'posted' => $post0 + 30,
        'remote' => '127.0.0.1',
        'source' => undef,
    });

    ok ! defined $it,
        'it should not save undefined body on 2:5:Page1.';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page1',
        'rev' => 1,
        'posted' => $post0 + 30,
        'remote' => '127.0.0.1',
        'source' => 'conflict Page1 rev1.',
    });

    ok exists $it->{'mine'} && exists $it->{'orig'} && exists $it->{'page'},
        'it should skip to save on conflict.';

    is_deeply $it->{'mine'}, $wiki0->page->new({
        'id' => 5, 'rev' => 1, 'title' => 'Page1', 'posted' => $post0 + 30,
        'remote' => 'alice', 'source' => 'conflict Page1 rev1.',
    }), 'it should return mime of conflict.';

    is_deeply $it->{'orig'}, $wiki0->page->new({
        'id' => 5, 'rev' => 1, 'title' => 'Page1', 'posted' => $post0 + 10,
        'remote' => 'alice', 'source' => 'test page1 rev1.',
        'summary' => 'test page1 b', 'content' => q(),
    }), 'it should return orig of conflict.';

    is_deeply $it->{'page'}, $wiki0->page->new({
        'id' => 5, 'rev' => 2, 'title' => 'Page1', 'posted' => $post0 + 20,
        'remote' => 'alice', 'source' => 'test page1 rev2.',
        'summary' => 'test page1 b', 'content' => q(),
    }), 'it should return page of conflict.';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 5});

    ok ref $it && $it->{'page'}->can('id'),
        'its page should find page 2:5:Page1.';

    is $it->{'page'}->rev, 2,
        'its rev should also be 2.';

    is $it->{'page'}->id, 5,
        'its id should be 5.';

    is $it->{'page'}->title, 'Page1',
        'its title should be Page1.';

    is $it->{'page'}->posted, $post0 + 20,
        'its posted should also be post10 + 20.';

    is $it->{'page'}->remote, 'alice',
        'its remote should be "alice".';

    is $it->{'page'}->summary, 'test page1 b',
        'its source should also be "test page1 b"';

    is $it->{'page'}->content, "\n<p>test page1 rev2.</p>\n",
        'its content should also be "<p>test page1 rev2.</p>"';

    is_deeply $it->{'page'}->rel,
        [$wiki0->page->new({'id' => 6, 'rev' => 0, 'title' => 'Page2'}),
         $wiki0->page->new({'id' => 7, 'rev' => 0, 'title' => 'Page3'})],
        'its rel should also be [0:6:Page2, 0:7:Page3].';

    is $it->{'page'}->source, 'test page1 rev2.',
        'its source should also be "test page1 rev2."';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 c',
            '.content' => "\n<p>test page1 rev3.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page4'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page1',
        'rev' => 2,
        'posted' => $post0 + 30,
        'remote' => '127.0.0.1',
        'source' => 'test page1 rev3.',
    });

    ok ref $it && exists $it->{'page'} && ! exists $it->{'orig'},
        'it should save 3:5:Page1.';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 5});

    ok ref $it && $it->{'page'}->can('id'),
        'its page should find page 3:5:Page1.';

    is $it->{'page'}->rev, 3,
        'its rev should be 3.';

    is $it->{'page'}->id, 5,
        'its id should be 5.';

    is $it->{'page'}->title, 'Page1',
        'its title should be Page1.';

    is $it->{'page'}->posted, $post0 + 30,
        'its posted should be post10 + 30.';

    is $it->{'page'}->remote, 'alice',
        'its remote should be "alice".';

    is $it->{'page'}->summary, 'test page1 c',
        'its source should be "test page1 c"';

    is $it->{'page'}->content, "\n<p>test page1 rev3.</p>\n",
        'its content should be "<p>test page1 rev3.</p>"';

    is_deeply $it->{'page'}->rel,
        [$wiki0->page->new({'id' => 8, 'rev' => 0, 'title' => 'Page4'}),
         $wiki0->page->new({'id' => 7, 'rev' => 0, 'title' => 'Page3'})],
        'its rel should be [0:8:Page4, 0:7:Page3].';

    is $it->{'page'}->source, 'test page1 rev3.',
        'its source should be "test page1 rev3."';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page3 d',
            '.content' => "\n<p>test page3 rev4.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page1'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page3',
        'rev' => 0,
        'posted' => $post0 + 40,
        'remote' => '127.0.0.1',
        'source' => 'test page3 rev4.',
    });

    ok ref $it && exists $it->{'page'} && ! exists $it->{'orig'},
        'it should save 4:7:Page3.';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 5});

    ok ref $it && $it->{'page'}->can('id'),
        'its page should find page 3:5:Page1.';

    is $it->{'page'}->rev, 3,
        'its rev should be 3.';

    is $it->{'page'}->id, 5,
        'its id should be 5.';

    is $it->{'page'}->title, 'Page1',
        'its title should be Page1.';

    is $it->{'page'}->posted, $post0 + 30,
        'its posted should be post10 + 30.';

    is $it->{'page'}->remote, 'alice',
        'its remote should be "alice".';

    is $it->{'page'}->summary, 'test page1 c',
        'its source should be "test page1 c"';

    is $it->{'page'}->content, "\n<p>test page1 rev3.</p>\n",
        'its content should be "<p>test page1 rev3.</p>"';

    is_deeply $it->{'page'}->rel,
        [$wiki0->page->new({'id' => 8, 'rev' => 0, 'title' => 'Page4'}),
         $wiki0->page->new({'id' => 7, 'rev' => 4, 'title' => 'Page3'})],
        'its rel should be [0:8:Page4, 4:7:Page3].';

    is $it->{'page'}->source, 'test page1 rev3.',
        'its source should be "test page1 rev3."';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 7});

    ok ref $it && $it->{'page'}->can('title'),
        'its page should find page 4:7:Page3.';

    is $it->{'page'}->rev, 4,
        'its rev should be 4.';

    is $it->{'page'}->id, 7,
        'its id should be 7.';

    is $it->{'page'}->title, 'Page3',
        'its title should be Page3.';

    is $it->{'page'}->posted, $post0 + 40,
        'its posted should be post10 + 40.';

    is $it->{'page'}->remote, 'alice',
        'its remote should be "alice".';

    is $it->{'page'}->summary, 'test page3 d',
        'its source should be "test page3 d"';

    is $it->{'page'}->content, "\n<p>test page3 rev4.</p>\n",
        'its content should be "<p>test page3 rev4.</p>"';

    is_deeply $it->{'page'}->rel,
        [$wiki0->page->new({'id' => 5, 'rev' => 3, 'title' => 'Page1'}),
         $wiki0->page->new({'id' => 7, 'rev' => 4, 'title' => 'Page3'})],
        'its rel should be [3:5:Page1, 4:7:Page3].';

    is $it->{'page'}->source, 'test page3 rev4.',
        'its source should be "test page3 rev4."';
}

{
    my $wiki = $wiki0->new({%{$wiki0},
        'converter' => (bless {
            '.summary' => 'test page1 b',
            '.content' => "\n<p>test page1 rev2.</p>\n",
            '.rel' => [
                $wiki0->page->new({'title' => 'Page2'}),
                $wiki0->page->new({'title' => 'Page3'}),
            ],
        }, 'Mock::Converter'),
        'user' => Lamawiki::Cookie->new({'name' => 'alice'}),
    });
    my $it = $wiki->page->save($wiki, {
        'title' => 'Page1',
        'rev' => 3,
        'posted' => $post0 + 50,
        'remote' => '127.0.0.1',
        'source' => '',
    });

    ok ref $it && exists $it->{'page'} && ! exists $it->{'orig'},
        'it should delete 3:5:Page1.';
}

{
    my $it = $wiki0->page->find($wiki0, 'id', {'id' => 5});

    ok ref $it && $it->{'page'}->can('id'),
        'its page should find page 5:5:Page1.';

    is $it->{'page'}->rev, 5,
        'its rev should be 5.';

    is $it->{'page'}->id, 5,
        'its id should be 5.';

    is $it->{'page'}->title, 'Page1',
        'its title should be Page1.';

    is $it->{'page'}->posted, $post0 + 20,
        'its posted should be post10 + 20.';

    is $it->{'page'}->remote, 'alice',
        'its remote should be "alice".';

    is $it->{'page'}->summary, 'test page1 b',
        'its source should be "test page1 b"';

    is $it->{'page'}->content, "\n<p>test page1 rev2.</p>\n",
        'its content should be "<p>test page1 rev2.</p>"';

    is_deeply $it->{'page'}->rel,
        [$wiki0->page->new({'id' => 6, 'rev' => 0, 'title' => 'Page2'}),
         $wiki0->page->new({'id' => 7, 'rev' => 4, 'title' => 'Page3'})],
        'its rel should be [0:6:Page2, 4:7:Page3].';

    is $it->{'page'}->source, 'test page1 rev2.',
        'its source should be "test page1 rev2."';
}

