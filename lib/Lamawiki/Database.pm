package Lamawiki::Database;
use strict;
use warnings;
use Carp;
use Encode;
use Lamawiki::Strftime qw(strftime);
use DBI qw(:sql_types);

our $VERSION = '0.02';

sub new { return bless {%{$_[1] || +{}}}, ref $_[0] || $_[0] }
sub dbh { return @_ > 1 ? ($_[0]{'dbh'} = $_[1]) : $_[0]{'dbh'} }
sub module { return $_[0]{'module'} }
sub sth    { return $_[0]{'sth'} }
sub proc   { return $_[0]{'proc'} }

sub merge_module {
    my($self, %h) = @_;
    my $type   = delete $h{'type'} || +{};
    my $create = delete $h{'create_table'} || q();
    my $module = $self->module || +{'type' => {}, 'create_table' => q()};
    return $self->new({
        %{$self},
        'module' => {
            %{$module},
            'type' => {%{$module->{'type'}}, %{$type}},
            'create_table' => $module->{'create_table'} . $create,
            %h,
        },
    });
}

sub begun_work { return shift->dbh->{'BegunWork'} }
sub begin_work { return shift->dbh->begin_work }
sub commit     { return shift->dbh->commit }
sub rollback   { return shift->dbh->rollback }

sub last_insert_id {
    my($self, $k) = @_;
    return $self->dbh->last_insert_id(@{$self->module->{$k}});
}

sub get_or_set {
    my($self, $table, $select, $arg, $yield) = @_;
    my $begun = $self->begun_work;
    $begun or $self->begin_work;
    my $g = $self->call("$table.select_$select", $arg)->[0];
    my $h = $yield ? $yield->($g) : $arg;
    if (! $g && $h) {
        $g = $h;
        $self->call("$table.insert", $g);
        if (my $pk = $self->module->{"$table.primary_key"}) {
            $g = {%{$g}, $pk->[3] => $self->last_insert_id("$table.primary_key")};
        }
    }
    $begun or ($h ? $self->commit : $self->rollback);
    return $g;
}

sub replace {
    my($self, $table, $select, $arg, $yield) = @_;
    my $begun = $self->begun_work;
    $begun or $self->begin_work;
    my $g = $self->call("$table.select_$select", $arg)->[0];
    my $h = $yield ? $yield->($g) : $arg;
    if (! $g && $h) {
        $g = $h;
        $self->call("$table.insert", $g);
        if (my $pk = $self->module->{"$table.primary_key"}) {
            $g = {%{$g}, $pk->[3] => $self->last_insert_id("$table.primary_key")};
        }
    }
    elsif ($g && $h) {
        $g = $h;
        $self->call("$table.update", $g);
    }
    $begun or ($h ? $self->commit : $self->rollback);
    return $g;
}

sub call {
    my($self, $proc, $arg) = @_;
    my $stx = $self->prepare($proc);
    my $state = $stx->execute($arg);
    return $state if ! $self->module->{$proc}[1];
    my $a = [];
    while (my $h = $stx->fetchrow) {
        push @{$a}, $h;
    }
    return $a;
}

sub prepare {
    my($self, $proc) = @_;
    ref $self->module->{$proc} eq 'ARRAY' or croak "Lamawiki::Database cannot proc '$proc'.";
    my $sth = $self->dbh->prepare($self->module->{$proc}[0]) or croak $self->dbh->errstr;
    return $self->new({'module' => $self->module, 'proc' => $proc, 'sth' => $sth});
}

sub execute {
    my($self, $arg) = @_;
    my $typeof = $self->module->{'type'};
    my $timef = '%Y-%m-%d %H:%M:%S';
    my(undef, undef, @param) = @{$self->module->{$self->proc}};
    for my $i (0 .. $#param) {
        my($v, $t) = ($arg->{$param[$i]}, $typeof->{$param[$i]});
        $v = ! defined $v ? $v
           : $t == SQL_VARCHAR ? encode_utf8($v)
           : $t == SQL_DATETIME ? strftime($timef, $v)
           : $v;
        $self->sth->bind_param($i + 1, $v, $t);
    }
    return $self->sth->execute;
}

sub fetchrow {
    my($self) = @_;
    my $typeof = $self->module->{'type'};
    my $col = $self->module->{$self->proc}[1];
    my $row = $self->sth->fetchrow_arrayref or return;
    my $h = {};
    for my $i (0 .. $#{$col}) {
        my($k, $v, $t) = ($col->[$i], $row->[$i], $typeof->{$col->[$i]});
        $h->{$k} = ! defined $v ? $v
                 : $t == SQL_VARCHAR ? decode_utf8($v)
                 : $t == SQL_DATETIME ? strftime('%s', $v)
                 : $v;
    }
    return $h;
}

sub fixup {
    my($self, $sql) = @_;
    my $lex = qr/^(?=CREATE|DROP|DELETE|INSERT|REPLACE|UPDATE|BEGIN|COMMIT|ROLLBACK)/msx;
    for my $stmt (split m/$lex/msx, $sql) {
        $self->dbh->do($stmt);
    }
    return $self;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Database - DBI helper.

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

