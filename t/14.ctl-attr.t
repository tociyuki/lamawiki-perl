use strict;
use warnings;
use Test::More tests => 7;

BEGIN { use_ok 'Lamawiki::Controller' }

can_ok 'Lamawiki::Controller', qw(new wiki layout view env call);

{
    package Mock::Lamawiki;
    sub new { return bless +{%{$_[1] || +{}}}, ref $_[0] || $_[0] }

    package Mock::View;
    sub new { return bless +{%{$_[1] || +{}}}, ref $_[0] || $_[0] }

    package Mock::Layout;
    sub new { return bless +{%{$_[1] || +{}}}, ref $_[0] || $_[0] }
}

{
    my $it = Lamawiki::Controller->new({
        'wiki' => Mock::Lamawiki->new,
        'layout' => Mock::Layout->new,
        'view' => Mock::View->new,
        'env' => {'SCRIPT_NAME' => '/test'},
    });

    ok ref $it && $it->isa('Lamawiki::Controller'),
        'its new should create an instance of it.';
    is ref $it->wiki, 'Mock::Lamawiki',
        'its wiki should be injected.';
    is ref $it->layout, 'Mock::Layout',
        'its wiki should be injected.';
    is ref $it->view, 'Mock::View',
        'its view should be injected.';
    is_deeply $it->env, {'SCRIPT_NAME' => '/test'},
        'its env should be injected.';
}

