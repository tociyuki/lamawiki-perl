#!/usr/bin/env perl

package Lamawiki::Main;
use strict;
use warnings;
use File::Spec;
use lib qw(./lib);
use Lamawiki;
use Lamawiki::Sqlite;
use Lamawiki::Tokenbucket;
use Lamawiki::Htpasswd;
use Lamawiki::Capability;
use Lamawiki::Cookie;
use Lamawiki::Page;
use Lamawiki::Interwiki;
use Lamawiki::Liq;
use Lamawiki::Converter;
use Lamawiki::Layout;
use Lamawiki::Controller;

our $VERSION = '0.01';

my $CONFIG = {
    # sqlite3 master database file
    'dbname' => File::Spec->catfile(qw[. data pages.db]),

    # allow a post per period (seconds) after burst posts.
    # comment out `sch => {...},` setting to diable blocking. 
    'sch' => {'burst' => 3, 'period' => 12*3600},
    # max size of post body
    'maxpost' => 128*1024, # bytes of octets

    # comment out `auth => {...}` or `session => {...}` to forbidden /signin
    # signin md5 htpasswd file
    'auth' => {'path' => File::Spec->catfile(qw[. data wikipasswd])},
    # session cookie lifetime (seconds)
    'session' => {'lifetime' => 12*3600},

    # drop anonymous without sigin posts after the last signin by master role user.
    'protect_after' => 14*24*3600, # seconds (0 to disable)

    # allow/deny editings by anonymous without sigin.
    'anonymous.edit' => 0,   # 0: deny anonymous edit, 1: allow
    # avail following two settings if 'anonymous.edit' => 1
    'anonymous.insert' => 0, # 0: deny anonymous insert, 1: allow
    'anonymous.delete' => 0, # 0: deny anonymous delete, 1: allow

    # role of signin users (default not master)
    'role' => {
        'webmaster' => 'master', # change 'webmaster' to your name
    },

    # domain of page by regexp of title (default public)
    #   public:  can edit anonymous
    #   protect: can edit only by signin user
    #   private: can edit only by signin master role user
    'domain' => [
        'InterWikiName' => 'private',
        #'Top' => 'protect',
        # '.*' => 'protect',
    ],

    # white list of link patterns for anonymous posts.
    'link_ok' => [
        qr/[^.]+?[.](?:net|org|edu|gov)/msx,
        qr/[^.]+?[.](?:ne|or|ac|lg|go)[.][a-z]{2}/msx,
        qr/(?:c2|github|twitter|facebook)[.]com/msx,
        qr/(?:google|yahoo)[.](?:com|co[.][a-z]{2})/msx,
        qr/(?:sourceforge|slashdot)[.]jp/msx,
    ],

    # title of the special pages.
    'default.title' => 'Top',
    'interwiki.title' => 'InterWikiName',
    'all.title' => 'All',
    'recent.title' => 'Recent',

    # number of entries for recent and other list.
    'recent.limit' => 20,

    # template directory
    'view' => {'dir' => File::Spec->catdir(qw[. view ja])},

    # {{STATIC}} location for *.css and *.js files.
    'staticlocation' => '/static',
};

sub make_wiki_engine {
    my($config) = @_;
    my $dbname = $config->{'dbname'};
    return Lamawiki::Controller->new({
        'wiki' => Lamawiki->new({
            'config' => $config,
            'db' => Lamawiki::Sqlite->connect("dbi:SQLite:dbname=$dbname", q(), q(), sub{
                my($db) = @_;
                $db->fixup($db->module->{'create_table'});
                for my $q (qw[default interwiki all recent]) {
                    $db->call('titles.insert', {'title' => $config->{"${q}.title"}});
                }
            }),
            'sch' => $config->{'sch'}
                ? Lamawiki::Tokenbucket->new($config->{'sch'}) : undef,
            'auth' => $config->{'auth'}
                ? Lamawiki::Htpasswd->new($config->{'auth'}) : undef,
            'session' => $config->{'session'}
                ? Lamawiki::Cookie->new($config->{'session'}) : undef,
            'capability' => Lamawiki::Capability->new,
            'page' => Lamawiki::Page->new,
            'interwiki' => Lamawiki::Interwiki->new,
            'converter' => Lamawiki::Converter->new,
        }),
        'view' => Lamawiki::Liq->new($config->{'view'}),
        'layout' => Lamawiki::Layout->new,
    });
}

if ($ENV{'GATEWAY_INTERFACE'}) { # CGI
    my $engine = make_wiki_engine($CONFIG);
    binmode STDIN; binmode STDOUT; binmode STDERR;
    my $env = {%ENV, 'psgi.input' => *STDIN, 'psgi.errors' => *STDERR};
    $env->{'PATH_INFO'} ||= q(); # see Plack::Handler::CGI
    if ($env->{'SCRIPT_NAME'} eq q(/)) {
        $env->{'SCRIPT_NAME'} = q();
        $env->{'PATH_INFO'} = q(/) . $env->{'PATH_INFO'};
    }
    my $res = $engine->call($env);
    print "Status: $res->[0]\x0d\x0a";
    while (my($k, $v) = splice @{$res->[1]}, 0, 2) {
        print "$k: $v\x0d\x0a";
    }
    print "\x0d\x0a";
    print @{$res->[2]};
}
else { # PSGI Application
    require Plack::Builder;
    my $engine = make_wiki_engine($CONFIG);
    my $builder = Plack::Builder->new;
    $builder->add_middleware('Plack::Middleware::Static',
        'path' => sub{ s{\A/static/}{}msx },
        'root' => File::Spec->catdir(qw[. static]),
    );
    my $app = $builder->to_app(sub{ $engine->call($_[0]) });
};

__END__

=pod

=head1 NAME

wiki.cgi - a wiki-engine

=head1 VERSION

0.01

=head1 SYNOPSIS

    $ htpasswd -cm data/wikipasswd webmaster
    $ plackup wiki.cgi

    $ firefox http://localhost:5000/signin

=head1 AUTHOR

MIZUTANI Tociyuki

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

