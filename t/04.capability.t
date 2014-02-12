use strict;
use warnings;
use Test::More tests => 241;
use Lamawiki;

BEGIN { use_ok 'Lamawiki::Capability' }

{
    package Mock::Session;
    sub new { return bless +{%{$_[1] || +{}}}, ref $_[0] || $_[0] }
    sub name  { return $_[0]{'name'} }
    sub long_silence { return $_[0]{'long_silence'} }

    package Mock::Page;
    sub new { return bless +{%{$_[1] || +{}}}, ref $_[0] || $_[0] }
    sub title  { return $_[0]{'title'} }
    sub source { return $_[0]{'source'} }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => Mock::Session->new({'name' => 'master'}),
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 1,
            'anonymous.edit' => 0,
            'anonymous.insert' => 0,
            'anonymous.delete' => 0,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 1 insert 1 update 1 delete 1)],
        [qw(ProtectPage edit 1 insert 1 update 1 delete 1)],
        [qw(PublicPage  edit 1 insert 1 update 1 delete 1)],
        [qw(OtherPage   edit 1 insert 1 update 1 delete 1)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'master could link http://foo.com/ every domain name.',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "master should $action $title in protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => Mock::Session->new({'name' => 'test'}),
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 1,
            'anonymous.edit' => 0,
            'anonymous.insert' => 0,
            'anonymous.delete' => 0,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 1 insert 1 update 1 delete 1)],
        [qw(PublicPage  edit 1 insert 1 update 1 delete 1)],
        [qw(OtherPage   edit 1 insert 1 update 1 delete 1)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'user could link http://foo.com/ every domain name.',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "user should $action $title in protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => undef,
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 0,
            'anonymous.edit' => 1,
            'anonymous.insert' => 1,
            'anonymous.delete' => 1,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 0 insert 0 update 0 delete 0)],
        [qw(PublicPage  edit 1 insert 1 update 1 delete 1)],
        [qw(OtherPage   edit 1 insert 1 update 1 delete 1)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'anonymous could link http://example.net/ limited.',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "anonymous should $action $title in loose protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => undef,
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 0,
            'anonymous.edit' => 1,
            'anonymous.insert' => 1,
            'anonymous.delete' => 1,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 0 insert 0 update 0 delete 0)],
        [qw(PublicPage  edit 1 insert 0 update 0 delete 1)],
        [qw(OtherPage   edit 1 insert 0 update 0 delete 1)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'anonymous could not link http://displeased.com/',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "anonymous should $action $title displeased link in loose protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => undef,
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 0,
            'anonymous.edit' => 1,
            'anonymous.insert' => 1,
            'anonymous.delete' => 1,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 0 insert 0 update 0 delete 0)],
        [qw(PublicPage  edit 1 insert 1 update 1 delete 1)],
        [qw(OtherPage   edit 1 insert 1 update 1 delete 1)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $orig = $it->page->new({
        'source' => 'anonymous could link http://pleased.com/',
    });
    my $page = $it->page->new({
        'source' => 'anonymous could link http://pleased.com/',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action,
                $orig->new({%{$orig}, 'title' => $title}),
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "anonymous should $action $title pleased link in loose protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => undef,
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 0,
            'anonymous.edit' => 0, # !
            'anonymous.insert' => 1,
            'anonymous.delete' => 1,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 0 insert 0 update 0 delete 0)],
        [qw(PublicPage  edit 0 insert 0 update 0 delete 0)],
        [qw(OtherPage   edit 0 insert 0 update 0 delete 0)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'anonymous could link http://example.net/',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "anonymous should $action $title in protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => undef,
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 14*24*3600, # 2 weeks
            'anonymous.edit' => 1,
            'anonymous.insert' => 1,
            'anonymous.delete' => 1,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 0 insert 0 update 0 delete 0)],
        [qw(PublicPage  edit 1 insert 1 update 1 delete 1)],
        [qw(OtherPage   edit 1 insert 1 update 1 delete 1)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'anonymous could link http://example.net/ limited.',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "anonymous should $action $title out of auto protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 1}), # !
        'capability' => Lamawiki::Capability->new,
        'user' => undef,
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 14*24*3600, # 2 weeks
            'anonymous.edit' => 1,
            'anonymous.insert' => 1,
            'anonymous.delete' => 1,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 0 insert 0 update 0 delete 0)],
        [qw(PublicPage  edit 0 insert 0 update 0 delete 0)],
        [qw(OtherPage   edit 0 insert 0 update 0 delete 0)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'anonymous could link http://example.net/ limited.',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "anonymous should $action $title on auto protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => undef,
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 0,
            'anonymous.edit' => 1,
            'anonymous.insert' => 0,
            'anonymous.delete' => 0,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 0 insert 0 update 0 delete 0)],
        [qw(PublicPage  edit 1 insert 0 update 1 delete 0)],
        [qw(OtherPage   edit 1 insert 0 update 1 delete 0)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'anonymous could link http://example.net/ limited.',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "anonymous should $action $title in light protect.";
        }
    }
}

{
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'session' => Mock::Session->new({'long_silence' => 0}),
        'capability' => Lamawiki::Capability->new,
        'user' => undef,
        'page' => Mock::Page->new,
        'config' => {
            'all.title' => 'All',
            'recent.title' => 'Recent',
            'protect_after' => 0,
            'anonymous.edit' => 1,
            'anonymous.insert' => 0,
            'anonymous.delete' => 0,
            'role' => {'master' => 'master'},
            'domain' => [
                'PrivatePage' => 'private',
                'ProtectPage' => 'protect',
                'PublicPage' => 'public',
                '.*' => 'protect', # !
            ],
            'link_ok' => [
                qr/[^.]+?[.](?:org|edu|gov)/msx,
            ],
        },
    });
    my @spec = (
        [qw(PrivatePage edit 0 insert 0 update 0 delete 0)],
        [qw(ProtectPage edit 0 insert 0 update 0 delete 0)],
        [qw(PublicPage  edit 1 insert 0 update 1 delete 0)],
        [qw(OtherPage   edit 0 insert 0 update 0 delete 0)],
        [qw(All         edit 0 insert 0 update 0 delete 0)],
        [qw(Recent      edit 0 insert 0 update 0 delete 0)],
    );
    my $page = $it->page->new({
        'source' => 'anonymous could link http://example.net/ limited.',
    });
    for my $a (@spec) {
        my($title, @actions) = @{$a};
        while (my($action, $expected) = splice @actions, 0, 2) {
            my $got = $it->capability->allow($it, $action, undef,
                $page->new({%{$page}, 'title' => $title}));
            if (! $expected) {
                ($got, $action) = (! $got, "not $action");
            }
            ok $got, "anonymous should $action $title in domain protect.";
        }
    }
}

