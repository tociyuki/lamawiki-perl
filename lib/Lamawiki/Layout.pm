package Lamawiki::Layout;
use strict;
use warnings;
use Carp;
use Encode;

our $VERSION = '0.02';

sub new  { return bless +{%{$_[1] || +{}}}, ref $_[0] || $_[0] }
sub wiki { return @_ > 1 ? ($_[0]{'wiki'} = $_[1]) : $_[0]{'wiki'} }
sub view { return @_ > 1 ? ($_[0]{'view'} = $_[1]) : $_[0]{'view'} }

my %WIKI_LAYOUT = (
    'include' => 'layout_include',
    'index'   => 'layout_index',
    'referer' => 'layout_referer',
    'toc'     => 'layout_toc',
    'nav'     => 'layout_nav',
);

sub filters {
    my($class, $wiki) = @_;
    $class = ref $class || $class;
    return (
        'LAYOUT' => sub{
            my($page, $view) = @_;
            my $self = $class->new({'wiki' => $wiki, 'view' => $view});
            $self->layout($page, q(), {$page->title => 1});
        },
    );
}

sub layout {
    my($self, $page, $x, $inc) = @_;
    my $r = $page->rev;
    my $t = $page->output;
    return "\n" if $t eq q();
    $t =~ s{(<h[1-6][ ]id="|<a[ ]href="\#)}{$1r$r}gmsx;
    my $toc = $t =~ s{\n<nav[ ]id="toc">(.*?)</nav>\n}{}msx ? $1 : q();
    my $gdiv = sub{
        my($name, $x) = @_;
        $name = $self->view->call('UNHTMLALL', $name);
        if ($name =~ m/\A(\w+(?:[-]\w+)*)(?:[:](.*))?\z/msx) {
            my($layout, $q) = ($1, defined $2 ? $2 : q());
            if (exists $WIKI_LAYOUT{$layout}) {
                my $f = $WIKI_LAYOUT{$layout};
                return $self->$f($x, $page, $q, $inc);
            }
        }
        return "\n";
    };
    $t =~ s{\n<div[ ]wiki="([^"]*)">(.*?)</div>\n}{$gdiv->($1, $2)}egmsx;
    if ($x ne q()) {
        my $u = $self->view->call('LOCATION', $page);
        $t = qq(\n<nav class="include">\n)
             . qq(<h1><a href="$u">$x</a></h1>$t</nav>\n);
    }
    return $t;
}

sub layout_include {
    my($self, $x, $page0, $q, $inc) = @_;
    return "\n" if $q eq q();
    if ($inc->{$q}) {
        my $x = $self->view->call('HTML', $q);
        return "\n<p>&gt;&gt;&gt; $x &lt;&lt;&lt;</p>\n";
    }
    my $page = $self->wiki->page->find($self->wiki, 'title', {'title' => $q})->{'page'};
    $page = $self->view->call('RESOLVE', $page);
    return $self->layout($page, $x, {%{$inc}, $q => 1});
}

sub layout_index {
    my($self, $x, $page0, $q) = @_;
    return "\n" if $q eq q();
    my $list = $self->wiki->page->findall($self->wiki, 'index', {'prefix' => $q});
    return "\n" if ! @{$list};
    return $self->view->render('layout-index.html', {'title' => $x, 'list' => $list});
}

sub layout_referer {
    my($self, $x, $page0, $q) = @_;
    $q = $q eq q() ? $page0->title : $q;
    my $list = $self->wiki->page->findall($self->wiki, 'title_ref', {'to_title' => $q});
    return "\n" if ! @{$list};
    return $self->view->render('layout-index.html', {'title' => $x, 'list' => $list});
}

sub layout_toc {
    my($self, $x, $page0, $q) = @_;
    return "\n" if $q eq q();
    my $page = $self->wiki->page->find($self->wiki, 'title', {'title' => $q})->{'page'};
    return "\n" if $page->rev <= 0;
    my $r = $page->rev;
    my $t = $page->content;
    $t =~ s{(<h[1-6][ ]id="|<a[ ]href="\#)}{$1r$r}gmsx;
    my $toc = $t =~ m{\n<nav[ ]id="toc">(.*?)</nav>\n}msx ? $1 : return "\n";
    my $path = $self->view->call('LOCATION', $page);
    $toc =~ s{<a[ ]href="\#}{<a href="$path\#}gmsx;
    return $toc if $x eq q();
    return qq(\n<nav class="toc">\n<h1>$x</h1>\n$toc</nav>\n);
}

sub layout_nav {
    my($self, $x, $page0, $q) = @_;
    my $parent = $q eq q() ? $page0
        : $self->wiki->page->find($self->wiki, 'title', {'title' => $q})->{'page'};
    $q = $q eq q() ? $page0->title : $q;
    return "\n" if $parent->rev <= 0;
    my $i = $q eq $page0->title ? -1 : -2;
    for my $j (0 .. $#{$parent->rel}) {
        if ($i == -2 && $parent->rel->[$j]->title eq $page0->title) {
            $i = $j;
        }
    }
    my $prev = $i - 1 >= 0 ? $parent->rel->[$i - 1] : q();
    my $next = $i + 1 >= 0 && $i + 1 <= $#{$parent->rel} ? $parent->rel->[$i + 1] : q();
    return $self->view->render('layout-nav.html', {
        'prev' => $prev, 'next' => $next, 'parent' => $parent,
        'title' => $x eq q() ? $q : $x,
    });
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Layout - Lamawiki::Liq filter to layout content from resolved page.

=head1 VERSION

0.02

=head1 AUTHOR

MIZUTANI Tociyuki

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

