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
    my $your = $self->_select($wiki, $h->{'title'}, $self->MAXREV);
    my $page = $self->new({
        'id' => $your->id, 'rev' => $h->{'rev'}, 'title' => $h->{'title'},
        'posted' => $h->{'posted'} ? $h->{'posted'} : $wiki->now,
        'remote' => $wiki->user ? $wiki->user->name
                  : $h->{'remote'} ? $h->{'remote'}
                  : q(),
        'source' => $h->{'source'},
    });
    if ($page->rev != $your->rev) {
        my $orig = $self->_select($wiki, $page->title, $page->rev);
        $begun or $wiki->db->rollback;
        return if $page->rev > $your->rev;
        return {'page' => $page, 'orig' => $orig, 'your' => $your};
    }
    my $f = $page->rev == 0 && $page->source ne q() ? 'insert'
          : $page->rev > 0  && $page->source eq q() ? 'delete'
          : $page->rev > 0  && $page->source ne $your->source ? 'update'
          : q();
    if (! $wiki->capability->allow($wiki, $f, $your, $page)) {
        $begun or $wiki->db->rollback;
        return;
    }
    if ($f) {
        $f = "_${f}";
        $page = $page->$f($wiki);
    }
    $begun or $wiki->db->commit;
    return {'page' => $page};
}

sub find_edit {
    my($self, $wiki, $h) = @_;
    my $r = $h->{'rev'};
    my $param = $wiki->page->find($wiki, 'title_rev', $h) or return;
    delete $param->{'prev'};
    if (defined $r && $param->{'page'}->rev != $r) {
        delete $param->{'latest'};
    }
    else {
        my $f = $param->{'page'}->rev == 0 ? 'insert' : 'update';
        if (! $wiki->capability->allow($wiki, $f, undef, $param->{'page'})) {
            delete $param->{'latest'};
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
        'id' => undef, 'title' => q(), 'rev' => $self->MAXREV + 1,
        'remote' => $s, 'rel' => $a, 'posted' => $wiki->now,
    })};
}

sub generate_all {
    my($self, $wiki) = @_;
    my $rel = $self->findall($wiki, 'all', {});
    return $self->new({
        %{$self}, 'rev' => $self->MAXREV + 1, 'posted' => $wiki->now,
        'rel' => $rel, 'resolver' => 'all',
    });
}

sub generate_recent {
    my($self, $wiki) = @_;
    my $rel = $self->findall($wiki, 'recent', {});
    @{$rel} = map { $_->new({%{$_}, 'source' => q(), 'content' => q()}) } @{$rel};
    return $self->new({
        %{$self}, 'rev' => $self->MAXREV + 1, 'posted' => $wiki->now,
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
    return if defined $r && ! ($self->is_rev($r) && $r > 0);
    if (defined $q) {
        return if ! $self->is_title($q);
        return if $wiki->interwiki && $wiki->interwiki->resolve($q);
        return if defined $r && $wiki->generater->{$q};
    }
    my($page, $prev, $latest);
    my $select_from_pages = $k eq 'id' || $k eq 'title' ? sub{
        my $g = $wiki->db->call("pages.select_$k", $h)->[0];
        $page = $g ? $self->new($g) : $self->empty($q, $id);
        $page->{'rel'} = [];
        return if $page->rev <= 0;
        my $a = $wiki->db->call('titles.select_id_rel', {'id' => $page->id});
        @{$page->rel} = map { $self->new($_) } @{$a};
        return;
    }
    : $k eq 'id_rev' || $k eq 'title_rev' ? sub{
        my $g = $wiki->db->call("pages.select_$k", $h)->[0];
        $page = $latest = $g ? $self->new($g) : $self->empty($q, $id);
        return if $page->rev <= 0;
        my $g0 = $wiki->db->call("pages.select_$k",
            {%{$h}, 'rev' => $page->rev - 1})->[0];
        $prev = $g0 && $self->new($g0);
        my $g1 = $wiki->db->call("pages.select_$k",
            {%{$h}, 'rev' => $wiki->page->MAXREV + 1})->[0];
        $latest = $g1 ? $self->new($g1) : $self->empty($page->title, $page->id);
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
    return +{'page' => $page, 'prev' => $prev, 'latest' => $latest};
}

sub _select {
    my($self, $wiki, $q, $r) = @_;
    $r = defined $r ? $r : $self->MAXREV;
    my $h = $wiki->db->call('pages.select_title_rev', {'title' => $q, 'rev' => $r})->[0];
    return $h ? $self->new($h) : $self->empty($q);
}

sub _insert { return shift->_update(@_) }

sub _update {
    my($self, $wiki) = @_;
    my $page = $self;
    if (! $page->id) {
        $page = $page->new({%{$page}, 'rev' => 0});
        $wiki->db->call('titles.insert', $page);
        $page = $page->new({%{$page}, 'id' => $wiki->db->last_insert_id('titles.primary_key')});
    }
    $wiki->db->call('sources.insert', $page);
    $page = $page->new({%{$page}, 'rev' => $wiki->db->last_insert_id('sources.primary_key')});
    return $page->_update_title_rel($wiki);
}

sub _delete {
    my($self, $wiki) = @_;
    $wiki->db->call('sources.delete', $self);
    my $page = $self->_select($wiki, $self->title);
    if ($page->rev > 0) {
        $wiki->db->call('sources.delete', $page);
        $wiki->db->call('sources.insert', $page);
        $page = $page->new({%{$page}, 'rev' => $wiki->db->last_insert_id('sources.primary_key')});
    }
    return $page->_update_title_rel($wiki);
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

