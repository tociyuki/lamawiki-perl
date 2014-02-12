package Lamawiki::Controller;
use strict;
use warnings;
use Encode;
use Digest::MD5 qw(md5_base64);

our $VERSION = '0.01';

my @LOCATIONS_REQUEST = (
    [qr{/signin}msx => 'call_signin'],
    [qr{/signout}msx => 'call_signout'],
    [qr{/([1-9][0-9]{0,8})}msx => 'call_id'],
    [qr{/([1-9][0-9]{0,8})/history}msx => 'call_id_history'],
    [qr{/([1-9][0-9]{0,8})/([1-9][0-9]{0,8})}msx => 'call_id_rev'],
    [qr{/}msx => 'call_root'],
);
my %POST_REQUEST = ('e' => 'post_edit', 'w' => 'post_write');

sub filters {
    my(undef, $wiki, $script) = @_;
    return (
        'DEFAULT' => sub{ $wiki->page->see_title($wiki) },
        'ALL'     => sub{ $wiki->page->see_title($wiki, $wiki->all_title) },
        'RECENT'  => sub{ $wiki->page->see_title($wiki, $wiki->recent_title) },
        'HISTORY?' => sub{ $wiki->page->is_rev($_[0]->rev) && $_[0]->rev },
        'EDIT?' => sub{
            my($page) = @_;
            $wiki->capability && $wiki->capability->allow($wiki, 'edit', undef, $page);
        },
        'INSERT?' => sub{
            my($page) = @_;
            $wiki->capability && $wiki->capability->allow($wiki, 'insert', undef, $page);
        },
        'RESOLVE' => sub{
            my($page, $v) = @_;
            my $t = q();
            if ($page->resolver) {
                $t = $v->render('content-' . $page->resolver . '.html', {'page' => $page});
            }
            else {
                my @loc;
                $t = $page->content;
                $t =~ s{<a[ ]href="([0-9]+)}
                  {q(<a href=").($loc[$1] ||= $v->call('LOCATION', $page->rel->[$1]))}egmsx;
            }
            return $page->new({%{$page}, 'output' => $t});
        },
        'SCRIPT' => sub{
            my(undef, $v) = @_;
            return $v->call('URI', $script);
        },
        'SIGNIN' => sub {
            my(undef, $v) = @_;
            return $v->execute('{{script URI}}/signin', {'script' => $script});
        },
        'SIGNOUT' => sub {
            my(undef, $v) = @_;
            return $v->execute('{{script URI}}/signout', {'script' => $script});
        },
        'LOCATION' => sub{
            my($page, $v) = @_;
            if ($wiki->interwiki) {
                my $u = $wiki->interwiki->resolve($page->title);
                return $u if $u;
            }
            if (! $page->id) {
                return $v->execute('{{script URI}}/?{{title URIALL}}',
                    {'script' => $script, 'title' => $page->title});
            }
            return $v->execute('{{script URI}}/{{id URIALL}}',
                {'script' => $script, 'id' => $page->id});
        },
        'HISTORY' => sub{
            my($page, $v) = @_;
            return $v->execute('{{script URI}}/{{id URIALL}}/history', {
                'script' => $script, 'id' => $page->id,
            });
        },
        'REVISION' => sub{
            my($page, $v) = @_;
            return $v->execute('{{script URI}}/{{id URIALL}}/{{r URIALL}}', {
                'script' => $script, 'id' => $page->id, 'r' => $page->rev,
            });
        },
        'REMOTE' => sub{
            my($s, $v) = @_;
            return $v->execute('{{script URI}}/?remote={{s URIALL}}', {
                'script' => $script, 's' => $s,
            });
        },
        'STATIC' => sub{
            return $wiki->config->{'staticlocation'};
        },
    );
}

sub new    { return bless {%{$_[1] || +{}}}, ref $_[0] || $_[0] }
sub wiki   { return $_[0]{'wiki'} }
sub layout { return $_[0]{'layout'} }
sub view   { return $_[0]{'view'} }
sub env    { return $_[0]{'env'} }
sub forbidden { return shift->response('forbidden.html', {}, 403) }

sub call {
    my($self, $env, $now) = @_;
    my %cookie = _split_cookie($env);
    my $m = $self->wiki->launch($now)->find_authenticate($cookie{'s'})->reload_interwiki;
    my $v = $self->view->merge_filters(
        $self->filters($m, $env->{'SCRIPT_NAME'}),
        $self->layout->filters($m),
    );
    my $c = $self->new({%{$self}, 'wiki' => $m, 'view' => $v, 'env' => $env});
    if (defined $cookie{'s'} && ! $m->user && $env->{'REQUEST_METHOD'} eq 'POST') {
        return $c->forbidden;
    }
    my $path = $env->{'PATH_INFO'} || q(/);
    eval{
        $path = decode('UTF-8', $path, Encode::FB_CROAK|Encode::LEAVE_SRC);
        1;
    } or return $c->forbidden;
    for my $x (@LOCATIONS_REQUEST) {
        my($location, $request) = @{$x};
        if ($path =~ m/\A$location\z/msx) {
            return $c->$request($1, $2);
        }
    }
    return $c->forbidden;
}

sub _split_cookie {
    my($env) = @_;
    return map { split /=/msx, $_, 2 }
            split /;\s*/msx, $env->{'HTTP_COOKIE'} || q();
}

sub call_signin {
    my($self) = @_;
    my $wiki = $self->wiki;
    return $self->see_other if ! $wiki->auth || ! $wiki->session;
    return $self->see_other if $wiki->user;
    if ($self->env->{'REQUEST_METHOD'} eq 'POST') {
        my $h = body_parameters($self->env, {}, $wiki->config->{'maxpost'});
        my $user = $wiki->session->signin($wiki, {
            %{$h}, 'remote' => $self->env->{'REMOTE_ADDR'},
        });
        if ($user) {
            return $self->set_cookie('s=' . $user->sesskey, $self->see_other);
        }
    }
    return $self->response('signin.html', {});
}

sub call_signout {
    my($self) = @_;
    my $wiki = $self->wiki;
    $wiki->user && $wiki->user->signout($wiki);
    return $self->set_cookie('s=; expires=Thu, 01-Jan-1970 00:00:00 GMT', $self->see_other);
}

sub call_root {
    my($self) = @_;
    my $wiki = $self->wiki;
    if ($self->env->{'REQUEST_METHOD'} eq 'POST') {
        my $param = body_parameters($self->env, {}, $wiki->config->{'maxpost'});
        my($c, @arg) = map { defined $_ ? $_ : q() } @{$param}{qw(c q r e t)};
        my $f = $POST_REQUEST{$c} or return $self->forbidden;
        return $self->$f(@arg);
    }
    else {
        my $param = query_parameters($self->env, {}, 'title');
        if (exists $param->{'remote'}) {
            my $h = $wiki->page->find_remote($wiki, $param->{'remote'});
            return $self->response('remote.html', $h);
        }
        my $page = $wiki->page->see_title($wiki, $param->{'title'});
        return $self->see_other($page) if defined $page->id;
        return $self->response('empty.html', {'page' => $page});
    }
}

sub call_id {
    my($self, $id) = @_;
    $self->env->{'REQUEST_METHOD'} eq 'GET' or return $self->see_other;
    my $wiki = $self->wiki;
    my $h = $wiki->page->find($wiki, 'id', {'id' => $id})
        or return $self->see_other;
    return $self->response('empty.html', $h) if ! $h->{'page'}->rev;
    my $res = $self->response('default.html', $h);
    return $self->add_etag('page' . $h->{'page'}->rev, $res);
}

sub call_id_rev {
    my($self, $id, $r) = @_;
    $self->env->{'REQUEST_METHOD'} eq 'GET' or return $self->see_other;
    my $wiki = $self->wiki;
    my $h = $wiki->page->find($wiki, 'id_rev', {'id' => $id, 'rev' => $r})
        or return $self->see_other;
    return $self->see_other($h->{'page'}) if $h->{'page'}->rev <= 0;
    return $self->see_rev($h->{'page'}) if $h->{'page'}->rev != $r;
    my $res = $self->response('rev.html', $h);
    return $self->add_etag('rev' . $h->{'page'}->rev, $res);
}

sub call_id_history {
    my($self, $id) = @_;
    $self->env->{'REQUEST_METHOD'} eq 'GET' or return $self->see_other;
    my $wiki = $self->wiki;
    my $h = $wiki->page->find_history($wiki, 'id', {'id' => $id})
        or return $self->see_other;
    return $self->response('history.html', $h);
}

sub post_edit {
    my($self, $q, $r) = @_;
    $r = $r eq q() ? undef : $r;
    my $wiki = $self->wiki;
    my $h = $wiki->page->find_edit($wiki, {'title' => $q, 'rev' => $r})
        or return $self->forbidden;
    return $self->see_rev($h->{'page'}) if defined $r && $h->{'page'}->rev != $r;
    return $self->response('editdeny.html', $h) if ! exists $h->{'latest'};
    return $self->response('edit.html', $h);
}

sub post_write {
    my($self, $q, $r, $e, $t) = @_;
    my $wiki = $self->wiki;
    my $user = $wiki->user;
    return $self->forbidden if $user && $e ne $user->token; # CSRF protection
    my $h = $wiki->page->save($wiki, {
        'title' => $q, 'rev' => $r, 'source' => $t, 'remote' => $self->env->{'REMOTE_ADDR'},
    }) or return $self->forbidden;
    return $self->response('conflict.html', $h, 409) if exists $h->{'your'};
    return $self->see_other($h->{'page'});
}

sub see_other {
    my($self, $page) = @_;
    my $wiki = $self->wiki;
    $page ||= $wiki->page->see_title($wiki);
    return [303, ['Location' => $self->view->call('LOCATION', $page)], []];
}

sub see_rev {
    my($self, $page) = @_;
    return [303, ['Location' => $self->view->call('REVISION', $page)], []];
}

sub response {
    my($self, $k, $param, $status) = @_;
    $param = {%{$param}, 'user' => $self->wiki->user};
    my $body = encode_utf8($self->view->render($k, $param));
    return [$status || 200, [
        'Content-Type' => 'text/html; charset=utf-8',
        'Content-Length' => length $body,
    ], [$body]];
}

sub add_etag {
    my($self, $prefix, $res) = @_;
    my $etag = sprintf q("%s-%s"), $prefix, md5_base64($res->[2][0]);
    my $noun = $self->env->{'HTTP_IF_NONE_MATCH'} || q();
    return [304, [], []] if $etag eq $noun;
    return [$res->[0], [@{$res->[1]}, 'ETag' => $etag], $res->[2]];
}

sub set_cookie {
    my($self, $s, $res) = @_;
    return [$res->[0], [@{$res->[1]}, 'Set-Cookie' => $s], $res->[2]];
}

sub query_parameters {
    my($env, $param, $key) = @_;
    my $fb = Encode::FB_CROAK|Encode::LEAVE_SRC;
    my $query = defined $env->{'QUERY_STRING'} ? $env->{'QUERY_STRING'} : q();
    for (split /[&;]/msx, $query) {
        my @kv = split /=/msx, $_, 2;
        @kv == 1 and unshift @kv, $key;
        return +{} if @kv != 2 || $kv[0] eq q();
        for (@kv) {
            tr/+/ /;
            s/%([0-9A-Fa-f]{2})/chr hex $1/egmsx;
            eval{ $_ = decode('UTF-8', $_, $fb); 1; } or return +{};
        }
        $param->{$kv[0]} = $kv[1];
    }
    return $param;
}

sub body_parameters {
    my($env, $param, $maxpost) = @_;
    my $hphrase = qr/"([^"]+)"|([^\s;]+)/msxo;
    my $fb = Encode::FB_CROAK|Encode::LEAVE_SRC;
    my $bnd = ($env->{'CONTENT_TYPE'} || q())
        =~ m{\Amultipart/form-data.*?\bboundary=$hphrase}msx ? $+ : return +{};
    my $length = $env->{'CONTENT_LENGTH'} or return +{};
    $length <= $maxpost or return +{};
    read $env->{'psgi.input'}, my($s), $length or return +{};
    $s =~ m/\G--$bnd\x0d\x0a/gcmsx or return +{};
    my $part = qr/\G(.*?\x0d\x0a)\x0d\x0a(.*?)\x0d\x0a--$bnd(--)?\x0d\x0a/msx;
    while ($s =~ m/$part/gcmsx) {
        my($h, $v, $e) = ($1, $2, $3);
        $h =~ s/\x0d\x0a([ \t]+)/$1 ? q( ) : "\n"/gmsx;
        my $t = $h =~ m/^Content-Disposition:\s+form-data;([^\n]*)/msx ? $1 : q();
        return +{} if $t =~ m/\sfilename=/msx;
        my $k = $t =~ m/\sname=$hphrase/msx ? $+ : return +{};
        $v =~ s/\x0d\x0a/\n/gmsx;
        eval{ $v = decode('UTF-8', $v, $fb); 1; } or return +{};
        $param->{$k} = $v;
        last if $e;
    }
    return $param;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Controller - the web controller

=head1 VERSION

0.01

=head1 AUTHOR

MIZUTANI Tociyuki

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

