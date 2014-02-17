package Lamawiki::Sqlite;
use strict;
use warnings;
use DBI qw(:sql_types);
use base qw(Lamawiki::Database);

our $VERSION = '0.02';

sub connect {
    my($class, $dsrc, $user, $auth, $yield) = @_;
    my $self = $class->new->define_module;
    my($dbname) = $dsrc =~ m/:dbname=([^:]+)/msx;
    my $already = -e $dbname;
    my $dbh = DBI->connect($dsrc, $user, $auth, {
        'RaiseError' => 1, 'PrintError' => 1, 'sqlite_unicode' => 0,
    });
    $self->dbh($dbh);
    if (! $already) {
        $yield->($self);
    }
    return $self;
}

sub define_module {
    my($self) = @_;
    return $self->define_titles
                ->define_relates
                ->define_sources
                ->define_pages
                ->define_cookies
                ->define_tbf;
}

sub define_pages {
    my($self) = @_;
    my $column = [qw(id title rev summary content posted remote source)];
    return $self->merge_module(
'type' => {
    'rev' => SQL_INTEGER, 'id' => SQL_INTEGER, 'to_id' => SQL_INTEGER,
    'summary' => SQL_VARCHAR, 'title' => SQL_VARCHAR, 'to_title' => SQL_VARCHAR,
    'posted' => SQL_DATETIME, 'remote' => SQL_VARCHAR,
    'content' => SQL_VARCHAR, 'source' => SQL_VARCHAR,
    'prefix' => SQL_VARCHAR, '-offset' => SQL_INTEGER, '-limit' => SQL_INTEGER,
},

'pages.select_id' => [<<'ENDSQL', $column, qw(id)],
SELECT T.id,T.title,T.rev,T.summary,T.content,S.posted,S.remote,coalesce(S.source,'')
  FROM titles AS T LEFT OUTER JOIN sources AS S ON S.rev=T.rev
  WHERE T.id=?;
ENDSQL

'pages.select_id_ref' => [<<'ENDSQL', $column, qw(to_id)],
SELECT F.id,F.title,F.rev,F.summary,'',S.posted,S.remote,''
  FROM relates AS R
  JOIN titles AS F ON F.id=R.id
  JOIN sources AS S ON S.rev=F.rev
  WHERE R.to_id=?
  ORDER BY F.title ASC;
ENDSQL

'pages.select_id_rev' => [<<'ENDSQL', $column, qw(rev id)],
SELECT T.id,T.title,coalesce(S.rev,0),T.summary,'',S.posted,S.remote,coalesce(S.source,'')
  FROM titles AS T LEFT OUTER JOIN sources AS S
    ON S.rev=(SELECT MAX(H.rev) FROM sources AS H WHERE H.id=T.id AND H.rev<=?)
  WHERE T.id=?;
ENDSQL

'pages.select_id_history' => [<<'ENDSQL', $column, qw(id)],
SELECT T.id,T.title,S.rev,T.summary,'',S.posted,S.remote,''
  FROM titles AS T JOIN sources AS S ON S.id=T.id
  WHERE T.id=?
  ORDER BY S.rev DESC;
ENDSQL

'pages.select_title' => [<<'ENDSQL', $column, qw(title)],
SELECT T.id,T.title,T.rev,T.summary,T.content,S.posted,S.remote,coalesce(S.source,'')
  FROM titles AS T LEFT OUTER JOIN sources AS S ON S.rev=T.rev
  WHERE T.title=?;
ENDSQL

'pages.select_title_ref' => [<<'ENDSQL', $column, qw(to_title)],
SELECT F.id,F.title,F.rev,F.summary,'',S.posted,S.remote,''
  FROM titles AS T
  JOIN relates AS R ON R.to_id=T.id
  JOIN titles AS F ON F.id=R.id
  JOIN sources AS S ON S.rev=F.rev
  WHERE T.title=?
  ORDER BY F.title ASC;
ENDSQL

'pages.select_title_rev' => [<<'ENDSQL', $column, qw(rev title)],
SELECT T.id,T.title,coalesce(S.rev,0),T.summary,'',S.posted,S.remote,coalesce(S.source,'')
  FROM titles AS T LEFT OUTER JOIN sources AS S
    ON S.rev=(SELECT MAX(H.rev) FROM sources AS H WHERE H.id=T.id AND H.rev<=?)
  WHERE T.title=?;
ENDSQL

'pages.select_title_history' => [<<'ENDSQL', $column, qw(title)],
SELECT T.id,T.title,S.rev,T.summary,'',S.posted,S.remote,''
  FROM titles AS T JOIN sources AS S ON S.id=T.id
  WHERE T.title=?
  ORDER BY S.rev DESC;
ENDSQL

'pages.select_feed' => [<<'ENDSQL', $column, qw(-offset -limit)],
SELECT T.id,T.title,T.rev,T.summary,T.content,S.posted,S.remote,S.source
  FROM titles AS T JOIN sources AS S ON S.rev=T.rev
  ORDER BY T.rev DESC
  LIMIT ?,?;
ENDSQL

'pages.select_all' => [<<'ENDSQL', $column],
SELECT T.id,T.title,T.rev,T.summary,'',S.posted,S.remote,''
  FROM titles AS T JOIN sources AS S ON S.rev=T.rev
  ORDER BY T.title ASC;
ENDSQL

'pages.select_recent' => [<<'ENDSQL', $column, qw(-limit)],
SELECT T.id,T.title,T.rev,T.summary,'',S.posted,S.remote,''
  FROM titles AS T JOIN sources AS S ON S.rev=T.rev
  ORDER BY T.rev DESC
  LIMIT ?;
ENDSQL

'pages.select_remote' => [<<'ENDSQL', $column, qw(remote -offset -limit)],
SELECT T.id,T.title,S.rev,T.summary,'',S.posted,S.remote,''
  FROM sources AS S JOIN titles AS T ON T.id=S.id
  WHERE S.remote=?
  ORDER BY S.rev DESC
  LIMIT ?,?;
ENDSQL

'pages.select_index' => [<<'ENDSQL', $column, qw(prefix)],
SELECT T.id,T.title,T.rev,T.summary,'',S.posted,S.remote,''
  FROM titles AS T JOIN sources AS S ON S.rev=T.rev
  WHERE T.title LIKE ? ESCAPE '^'
  ORDER BY T.title ASC;
ENDSQL
    );
}

sub define_titles {
    return shift->merge_module(
'type' => {
    'id' => SQL_INTEGER, 'to_id' => SQL_INTEGER, 'title' => SQL_VARCHAR,
    'rev' => SQL_INTEGER, 'summary' => SQL_VARCHAR, 'content' => SQL_VARCHAR,
},

'create_table' => <<'ENDSQL',
CREATE TABLE titles (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
   ,title VARCHAR(255) NOT NULL UNIQUE
   ,rev INTEGER NOT NULL
   ,summary VARCHAR(255) NOT NULL
   ,content TEXT NOT NULL
);
CREATE UNIQUE INDEX titles_all ON titles(title);
ENDSQL

'titles.primary_key' => [undef, undef, 'titles', 'id'],

'titles.insert' => [<<'ENDSQL', undef, qw(title)],
INSERT INTO titles(title,rev,summary,content) VALUES (?,0,'','');
ENDSQL

'titles.update' => [<<'ENDSQL', undef, qw(rev summary content id)],
UPDATE titles SET rev=?,summary=?,content=? WHERE id=?;
ENDSQL

'titles.select_id' => [<<'ENDSQL', [qw(id title rev)], qw(id)],
SELECT id,title,rev
  FROM titles
  WHERE id=?;
ENDSQL

'titles.select_id_rel' => [<<'ENDSQL', [qw(id title rev)], qw(id)],
SELECT T.id,T.title,T.rev
  FROM relates AS R JOIN titles AS T ON T.id=R.to_id
  WHERE R.id=?
  ORDER BY R.n ASC;
ENDSQL

'titles.select_title' => [<<'ENDSQL', [qw(id title rev)], qw(title)],
SELECT id,title,rev
  FROM titles
  WHERE title=?;
ENDSQL
    );
}

sub define_relates {
    return shift->merge_module(
'type' => {
    'id' => SQL_INTEGER, 'to_id' => SQL_INTEGER, 'n' => SQL_INTEGER, 
},

'create_table' => <<'ENDSQL',
CREATE TABLE relates (
    id INTEGER NOT NULL REFERENCES titles(id)
   ,to_id INTEGER NOT NULL REFERENCES titles(id)
   ,n INTEGER NOT NULL
   ,UNIQUE (id,to_id, n)
   ,PRIMARY KEY (id,to_id)
);
CREATE UNIQUE INDEX relates_to ON relates(to_id,id);
ENDSQL

'relates.insert' => [<<'ENDSQL', undef, qw(id to_id n)],
INSERT INTO relates(id,to_id,n) VALUES (?,?,?);
ENDSQL

'relates.delete' => [<<'ENDSQL', undef, qw(id)],
DELETE FROM relates WHERE id=?;
ENDSQL
    );
}

sub define_sources {
    return shift->merge_module(
'type' => {
    'rev' => SQL_INTEGER, 'id' => SQL_INTEGER, 'posted' => SQL_DATETIME,
    'remote' => SQL_VARCHAR, 'source' => SQL_VARCHAR,
},

'create_table' => <<'ENDSQL',
CREATE TABLE sources (
    rev INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
   ,id INTEGER NOT NULL REFERENCES titles(id)
   ,posted VARCHAR(20) NOT NULL
   ,remote VARCHAR(255) NOT NULL
   ,source TEXT NOT NULL
);
CREATE UNIQUE INDEX sources_history ON sources(id,rev);
CREATE UNIQUE INDEX sources_remote ON sources(remote,rev);
ENDSQL

'sources.primary_key' => [undef, undef, 'pages', 'rev'],

'sources.insert' => [<<'ENDSQL', undef, qw(id posted remote source)],
INSERT INTO sources(id,posted,remote,source) VALUES (?,?,?,?);
ENDSQL

'sources.delete' => [<<'ENDSQL', undef, qw(rev)],
DELETE FROM sources WHERE rev=?
ENDSQL
    );
}

sub define_cookies {
    return shift->merge_module(
'type' => {
    'sesskey' => SQL_VARCHAR, 'name' => SQL_VARCHAR, 'token' => SQL_VARCHAR,
    'posted' => SQL_DATETIME, 'remote' => SQL_VARCHAR, 'expires' => SQL_DATETIME,
},

'create_table' => <<'ENDSQL',
CREATE TABLE cookies (
    sesskey VARCHAR(255) NOT NULL UNIQUE PRIMARY KEY
   ,name VARCHAR(255) NOT NULL
   ,token VARCHAR(255) NOT NULL
   ,posted VARCHAR(20) NOT NULL
   ,remote VARCHAR(255) NOT NULL
   ,expires VARCHAR(20) NOT NULL
);
ENDSQL

'cookies.insert' => [<<'ENDSQL', undef, qw(sesskey name token posted remote expires)],
INSERT INTO cookies VALUES (?,?,?,?,?,?);
ENDSQL

'cookies.update' => [<<'ENDSQL', undef, qw(expires sesskey)],
UPDATE cookies SET expires=? WHERE sesskey=?;
ENDSQL

'cookies.select_auth' => [<<'ENDSQL', [qw(sesskey name token posted remote)], qw(sesskey expires)],
SELECT sesskey,name,token,posted,remote
  FROM cookies
  WHERE sesskey=? AND expires>?;
ENDSQL

'cookies.select_latest' => [<<'ENDSQL', [qw(posted)], qw(name)],
SELECT C.posted
  FROM cookies AS C
  WHERE C.name=? AND C.posted=(SELECT MAX(L.posted) FROM cookies AS L WHERE L.name=C.name);
ENDSQL
    );
}

sub define_tbf {
    return shift->merge_module(
'type' => {
    'remote' => SQL_VARCHAR, 'credit' => SQL_INTEGER,
},

'create_table' => <<'ENDSQL',
CREATE TABLE tbf (
    remote VARCHAR(255) NOT NULL UNIQUE PRIMARY KEY
   ,credit INTEGER NOT NULL
);
CREATE UNIQUE INDEX tbf_credit ON tbf(credit, remote);
ENDSQL

'tbf.insert' => [<<'ENDSQL', undef, qw(remote credit)],
INSERT INTO tbf VALUES (?,?);
ENDSQL

'tbf.update' => [<<'ENDSQL', undef, qw(credit remote)],
UPDATE tbf SET credit=? WHERE remote=?;
ENDSQL

'tbf.delete' => [<<'ENDSQL', undef, qw(credit)],
DELETE FROM tbf WHERE credit<?;
ENDSQL

'tbf.select_remote' => [<<'ENDSQL', [qw(remote credit)], qw(remote)],
SELECT remote,credit
  FROM tbf
  WHERE remote=?;
ENDSQL
    );
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Sqlite - the sqlite3 database accessing module.

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

