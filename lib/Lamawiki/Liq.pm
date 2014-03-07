package Lamawiki::Liq;
use strict;
use warnings;
use Carp;
use Encode;
use File::Spec;
use Lamawiki::Strftime qw(strftime);

our $VERSION = '0.02';

sub filter  { return @_ > 1 ? ($_[0]{'filter'} = $_[1]) : $_[0]{'filter'} }
sub dir     { return @_ > 1 ? ($_[0]{'dir'}    = $_[1]) : $_[0]{'dir'} }
sub dict    { return @_ > 1 ? ($_[0]{'dict'}   = $_[1]) : $_[0]{'dict'} }

sub new {
    my($class, $h) = @_;
    my $self = bless {%{$h || +{}}}, ref $class || $class;
    $self->{'filter'} ||= +{$self->core_filters};
    return $self;
}

sub merge_filters {
    my($self, @a) = @_;
    return $self->new({%{$self}, 'filter' => {%{$self->filter}, @a}});
}

sub render {
    my($self, $name, $param) = @_;;
    return $self->execute($self->template($name), $param);
}

sub template {
    my($self, $name) = @_;
    $self->dict($self->dict || +{});
    my $path = File::Spec->catfile($self->dir, $name);
    croak "template '$path'?" if ! (-f $path && -r _);
    my $mtime = (stat $path)[9];
    if (! $self->dict->{$name} || $self->dict->{$name}[0] < $mtime) {
        open my($fh), '<', $path or croak "template '$path'?";
        binmode $fh;
        my $octet = do{ local $/ = undef; <$fh> };
        close $fh;
        $self->dict->{$name} = [$mtime, decode_utf8($octet)];
    }
    return $self->dict->{$name}[1];
}

sub execute {
    my($self, $template, $param) = @_;
    $template =~ s{
        \{\{\s*
        (?: FOR([.][\w\-]+)\s+([\w.\-?]+)\s+IN\s+([\w.\-?]+(?:\s+[\w.\-?]+)*)
            \s*\}\}\n?(.*?)\{\{\s*ENDFOR\1
        |   IF([.][\w\-]+)\s+([\w.\-?]+(?:\s+[\w.\-?]+)*)
            \s*\}\}\n?(.*?)\{\{\s*(?:ELSE\5\s*\}\}\n?(.*?)\{\{\s*)?ENDIF\5
        |   ([\w.\-?]+(?:\s+[\w.\-?]+)*)
        )
        \s*\}\}\n?
    }{
        defined $1 ? $self->_for($2, $3, $4, $param)
      : defined $5 ? $self->_if($6, $7, $8, $param)
      :              $self->_get($9, $param)
    }egmsxo;
    return $template;
}

sub _get {
    my($self, $template, $param) = @_;
    my @a = split /\s+/msx, $template;
    exists $self->filter->{$a[-1]} or push @a, 'HTML';
    my $x = $self->_lookup(\@a, $param);
    return defined $x ? $x : q();
}

sub _if {
    my($self, $t0, $t1, $t2, $param) = @_;
    my $x = $self->_lookup([split /\s+/msx, $t0], $param);
    return $x ? $self->execute($t1, $param)
         : defined $t2 ? $self->execute($t2, $param)
         : q();
}

sub _for {
    my($self, $x, $t0, $t1, $param) = @_;
    my $a = $self->_lookup([split /\s+/msx, $t0], $param);
    $a = ref $a eq 'ARRAY' ? $a : [$a];
    return join q(), map {
        local $param->{$x} = $a->[$_];
        $self->execute($t1, $param)
    } 0 .. $#{$a};
}

sub _lookup {
    my($self, $keylist, $param) = @_;
    my $x = $param;
    for my $k (@{$keylist}) {
        $x = exists $self->filter->{$k} ? $self->call($k, $x, $param)
           : ref $x eq 'HASH' ? $x->{$k}
           : ref $x eq 'ARRAY' ? $x->[$k]
           : eval { $x->can($k) } ? $x->$k
           : q();
    }
    return $x;
}

sub call {
    my($self, $k, $x, @arg) = @_;
    return $self->filter->{$k}->($x, $self, @arg);
}

sub core_filters {
    my %esc = (qw[& &amp; < &lt; > &gt; " &quot;], q(') => '&#39;');
    my %unesc = reverse %esc;
    my $amp = qr/&(?:\#(?:[1-9][0-9]{1,9};|x[0-9A-Fa-f]{1,8};)|[A-Za-z][0-9A-Za-z]{0,15};)?/msx;
    return (
        'HTMLALL' => sub{
            my($s) = @_;
            $s =~ s/([&<>"'])/$esc{$1}/egmsxo;
            return $s;
        },
        'HTML' => sub{
            my($s) = @_;
            $s =~ s/($amp|[<>"'])/$esc{$1} || $1/egmsxo;
            return $s;
        },
        'URIALL'  => sub{
            my($s) = @_;
            utf8::is_utf8($s) and $s = encode_utf8($s);
            $s =~ s{([^0-9A-Za-z_\-./~])}{sprintf '%%%02X', ord $1}egmsxo;
            return $s;
        }, 
        'URI' => sub{
            my($s) = @_;
            utf8::is_utf8($s) and $s = encode_utf8($s);
            $s =~ s{(%[0-9A-Fa-f]{2})|(&(?:amp;)?)|([^0-9A-Za-z\-_.,:;+=()/~?\#])}
                   {$1 ? $1 : $2 ? '&amp;' : sprintf '%%%02X', ord $3}egmsxo;
            return $s;
        },
        'UNHTMLALL' => sub{
            my($s) = @_;
            $s =~ s/(&(?:amp|lt|gt|quot|\#39);)/$unesc{$1}/egmsx;
            return $s;
        },
        'RAW' => sub{ $_[0] },
        'NOT' => sub{ ! $_[0] },
        'YMDHM' => sub{ strftime('%Y-%m-%d %H:%M', $_[0]) },
        'LINES' => sub{ return [split /\n/msx, $_[0]] },
        'ENSP' => sub{
            my($s) = @_;
            return '&nbsp;' if $s eq q();
            $s =~ s/[ ]/&\#8194;/gmsxo;
            $s;
        },
    );
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Liq - the tiny template engine.

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

