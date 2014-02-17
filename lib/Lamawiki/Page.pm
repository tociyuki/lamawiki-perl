package Lamawiki::Page;
use strict;
use warnings;
use Encode;

our $VERSION = '0.01';

sub MAXREV   { return 999999999 }
sub new      { return bless {%{$_[1] || +{}}}, ref $_[0] || $_[0] }
sub rev      { return @_ > 1 ? ($_[0]{'rev'}      = $_[1]) : $_[0]{'rev'} }
sub posted   { return @_ > 1 ? ($_[0]{'posted'}   = $_[1]) : $_[0]{'posted'} }
sub remote   { return @_ > 1 ? ($_[0]{'remote'}   = $_[1]) : $_[0]{'remote'} }
sub id       { return @_ > 1 ? ($_[0]{'id'}       = $_[1]) : $_[0]{'id'} }
sub title    { return @_ > 1 ? ($_[0]{'title'}    = $_[1]) : $_[0]{'title'} }
sub summary  { return @_ > 1 ? ($_[0]{'summary'}  = $_[1]) : $_[0]{'summary'} }
sub source   { return @_ > 1 ? ($_[0]{'source'}   = $_[1]) : $_[0]{'source'} }
sub content  { return @_ > 1 ? ($_[0]{'content'}  = $_[1]) : $_[0]{'content'} }
sub output   { return @_ > 1 ? ($_[0]{'output'}   = $_[1]) : $_[0]{'output'} }
sub rel      { return @_ > 1 ? ($_[0]{'rel'}      = $_[1]) : $_[0]{'rel'} }
sub resolver { return @_ > 1 ? ($_[0]{'resolver'} = $_[1]) : $_[0]{'resolver'} }

sub empty {
    my($self, $q, $id) = @_;
    return $self->new({
        'rev' => 0, 'title' => $q, 'id' => $id,
        'posted' => undef, 'remote' => undef,
        'summary' => q(), 'content' => q(), 'source' => q(),
    })
}

sub is_id  { return defined $_[1] && $_[1] =~ m/\A[1-9][0-9]{0,8}\z/msx }
sub is_rev { return defined $_[1] && $_[1] =~ m/\A(?:0|[1-9][0-9]{0,8})\z/msx }

sub is_title {
    my($self, $q) = @_;
    return if ! defined $q;
    return if $q =~ m/https?:|f(?:tps?|ile):|script:|data:|mailto:/msxi;
    return if $q !~ m{\A
        [^\P{Graph}!"\#\$%&'+,\-./:;<=>?\@\[\\\]^`{|}~]
        [^\P{Graph}\#<>?\@\[\\\]{|}]*(?:[ ]{1,4}[^\P{Graph}\#<>?\@\[\\\]{|}]+)*
    \z}msx;
    return (length encode_utf8($q)) < 256;
}

sub see_title {
    my($self, $wiki, $q) = @_;
    $q = $self->is_title($q) ? $q : $wiki->default_title;
    my $h = $wiki->db->call('titles.select_title', {'title' => $q})->[0];
    return $self->new({
        'id' => $h ? $h->{'id'} : undef,
        'title' => $q,
        'rev' => $h ? $h->{'rev'} : 0,
    });
}

sub save {
    my($self, $wiki, $h) = @_;
    return if ! $self->is_title($h->{'title'}) || ! $self->is_rev($h->{'rev'});
    return if ! defined $h->{'source'};
    return if $wiki->interwiki && $wiki->interwiki->resolve($h->{'title'});
    return if exists $wiki->generater->{$h->{'title'}};
    return if ! $wiki->capability;
    return if ! $wiki->user && $wiki->sch && ! $wiki->sch->pass($wiki, $h->{'remote'}, $wiki->now);
    my $begun = $wiki->db->begun_work;
    $begun or $wiki->db->begin_work;
    my $param = $self->find($wiki, 'title_rev', {'title' => $h->{'title'}, 'rev' => $h->{'rev'}});
    my $page = $param->{'page'};
    my $orig = $param->{'orig'};
    my $prev = $param->{'prev'};
    my $mine = $self->new({
        'id' => $page->id, 'rev' => $h->{'rev'}, 'title' => $h->{'title'},
        'posted' => $h->{'posted'} ? $h->{'posted'} : $wiki->now,
        'remote' => $wiki->user ? $wiki->user->name
                  : $h->{'remote'} ? $h->{'remote'}
                  : q(),
        'source' => $h->{'source'},
    });
    if ($mine->rev != $page->rev) {
        $begun or $wiki->db->rollback;
        return if $mine->rev > $page->rev;
        return {'mine' => $mine, 'orig' => $orig, 'page' => $page};
    }
    my $f = $mine->rev == 0 && $mine->source ne q() ? 'insert'
          : $mine->rev > 0  && $mine->source eq q() ? 'delete'
          : $mine->rev > 0  && $mine->source ne $page->source ? 'update'
          : q();
    if (! $wiki->capability->allow($wiki, $f, $page, $mine)) {
        $begun or $wiki->db->rollback;
        return;
    }
    if ($f eq 'delete') {
        if ($mine->rev > 0) {
            $wiki->db->call('sources.delete', $mine);
        }
        $mine = $prev;
        if ($mine->rev > 0) {
            $wiki->db->call('sources.delete', $mine);
        }
    }
    if ($f) {
        $mine = $mine->_insert($wiki)->_update_title_rel($wiki);
    }
    $begun or $wiki->db->commit;
    return {'page' => $mine};
}

sub find_edit {
    my($self, $wiki, $h) = @_;
    my $r = $h->{'rev'};
    my $param = $wiki->page->find($wiki, 'title_rev', $h) or return;
    delete $param->{'prev'};
    if (defined $r && $param->{'orig'}->rev != $r) {
        delete $param->{'page'};
    }
    else {
        my $f = $param->{'page'}->rev == 0 ? 'insert' : 'update';
        if (! $wiki->capability->allow($wiki, $f, $param->{'page'})) {
            delete $param->{'page'};
        }
    }
    return $param;
}

sub find_history {
    my($self, $wiki, $k, $h) = @_;
    my $a = $self->findall($wiki, $k . '_history', $h);
    @{$a} or return;
    return +{'page' => $a->[0]->new({%{$a->[0]}, 'rel' => $a})};
}

sub find_remote {
    my($self, $wiki, $s) = @_;
    my $a = $self->findall($wiki, 'remote', {'remote' => $s});
    return +{'page' => $self->new({
        'id' => undef, 'title' => q(), 'rev' => -1,
        'remote' => $s, 'rel' => $a, 'posted' => $wiki->now,
    })};
}

sub generate_all {
    my($self, $wiki) = @_;
    my $rel = $self->findall($wiki, 'all', {});
    return $self->new({
        %{$self}, 'rev' => -1, 'posted' => $wiki->now,
        'rel' => $rel, 'resolver' => 'all',
    });
}

sub generate_recent {
    my($self, $wiki) = @_;
    my $rel = $self->findall($wiki, 'recent', {});
    @{$rel} = map { $_->new({%{$_}, 'source' => q(), 'content' => q()}) } @{$rel};
    return $self->new({
        %{$self}, 'rev' => -1, 'posted' => $wiki->now,
        'rel' => $rel, 'resolver' => 'recent',
    });
}

sub findall {
    my($self, $wiki, $k, $h) = @_;
    $h ||= {};
    my $id = defined $h->{'id'} ? $h->{'id'} : $h->{'to_id'};
    my $q = defined $h->{'title'} ? $h->{'title'} : $h->{'to_title'};
    return [] if defined $id && ! $self->is_id($id);
    if (defined $q) {
        return [] if ! $self->is_title($q);
        return [] if $wiki->interwiki && $wiki->interwiki->resolve($q);
    }
    if (defined $h->{'prefix'}) {
        $h->{'prefix'} =~ s/([%_^])/^$1/gmsx;
        $h->{'prefix'} .= q(%);
    }
    $h->{'-offset'} ||= 0;
    $h->{'-limit'} ||= $wiki->config->{'recent.limit'};
    my $stx = $wiki->db->prepare("pages.select_$k");
    $stx->execute($h);
    my $a = [];
    while (my $r = $stx->fetchrow) {
        next if $wiki->interwiki && $wiki->interwiki->resolve($r->{'title'});
        push @{$a}, $self->new($r);
    }
    return $a;
}

sub find {
    my($self, $wiki, $k, $h) = @_;
    if (($k eq 'id_rev' || $k eq 'title_rev') && ! defined $h->{'rev'}) {
        $h = +{%{$h}, 'rev' => $self->MAXREV};
    }
    my($id, $q, $r) = @{$h}{qw(id title rev)};
    return if defined $id && ! $self->is_id($id);
    return if defined $r && ! $self->is_rev($r);
    if (defined $q) {
        return if ! $self->is_title($q);
        return if $wiki->interwiki && $wiki->interwiki->resolve($q);
        return if $wiki->generater->{$q} && $k eq 'title_rev';
    }
    my($page, $prev, $orig);
    my $select_from_pages = $k eq 'id' || $k eq 'title' ? sub{
        my $g = $wiki->db->call("pages.select_$k", $h)->[0];
        $page = $g ? $self->new($g) : $self->empty($q, $id);
        $page->{'rel'} = [];
        return if $page->rev <= 0;
        my $stx = $wiki->db->prepare('titles.select_id_rel');
        $stx->execute({'id' => $page->id});
        while (my $h = $stx->fetchrow) {
            push @{$page->rel}, $self->new($h);
        }
        return;
    }
    : $k eq 'id_rev' || $k eq 'title_rev' ? sub{
        my $stx = $wiki->db->prepare("pages.select_$k");
        $stx->execute($h);
        my $g0 = $stx->fetchrow;
        $orig = $g0 ? $self->new($g0) : $self->empty($q, $id);
        $stx->execute({%{$h}, 'rev' => $orig->rev - 1});
        my $g1 = $stx->fetchrow;
        $prev = $g1 ? $self->new($g1) : $self->empty($q, $id);
        $stx->execute({%{$h}, 'rev' => $self->MAXREV});
        my $g2 = $stx->fetchrow;
        $page = $g2 ? $self->new($g2) : $self->empty($q, $id);
        return;
    }
    : return;
    my $begun = $wiki->db->begun_work;
    $begun or $wiki->db->begin_work;
    $select_from_pages->();
    $begun or $wiki->db->commit;
    if (! defined $q) {
        return if ! $self->is_title($page->title);
        return if $wiki->interwiki && $wiki->interwiki->resolve($page->title);
    }
    my $gen = $wiki->generater->{$page->title};
    if ($k eq 'id' || $k eq 'title') {
        return +{'page' => $gen ? $gen->($wiki, $page) : $page};
    }
    return if $gen;
    return +{'page' => $page, 'prev' => $prev, 'orig' => $orig};
}

sub find_interwiki {
    my($self, $wiki, $q) = @_;
    my $h = $wiki->db->call('pages.select_title', {'title' => $q})->[0];
    return $h ? $self->new($h) : $self->empty($q);
}

sub _insert {
    my($self, $wiki) = @_;
    return $self if $self->source eq q();
    my $mine = $self;
    if (! $mine->id) {
        $mine = $mine->new({%{$mine}, 'rev' => 0});
        $wiki->db->call('titles.insert', $mine);
        my $id1 = $wiki->db->last_insert_id('titles.primary_key');
        $mine = $mine->new({%{$mine}, 'id' => $id1});
    }
    $wiki->db->call('sources.insert', $mine);
    my $r1 = $wiki->db->last_insert_id('sources.primary_key');
    return $mine->new({%{$mine}, 'rev' => $r1});
}

sub _update_title_rel {
    my($self, $wiki) = @_;
    my $page = $wiki->converter->convert($self);
    $wiki->db->call('titles.update', $page);
    $wiki->db->call('relates.delete', $page);
    my $rel = [];
    for my $i (0 .. $#{$page->rel}) {
        my $to = $page->new(
            $wiki->db->get_or_set('titles', 'title', $page->rel->[$i]),
        );
        $wiki->db->call('relates.insert',
            {'id' => $page->id, 'to_id' => $to->id, 'n' => $i + 1});
        push @{$rel}, $to;
    }
    return $page->new({%{$page}, 'rel' => $rel});
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Page - the page object.

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

