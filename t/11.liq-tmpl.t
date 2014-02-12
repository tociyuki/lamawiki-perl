use strict;
use warnings;
use Lamawiki::Liq;
use Lamawiki::Strftime qw(strftime);
use Test::More;
use lib qw(./t/lib);
use Lamawikix::Testutil qw(split_spec);

my $blocks = split_spec(qw(=== ---), do{ local $/ = undef; scalar <DATA> });

plan tests => 1 * @{$blocks};

for my $test (@{$blocks}) {
    my $liq = Lamawiki::Liq->new->merge_filters(
        'YMDHM' => sub{ strftime('%Y-%m-%d %H:%M', $_[0]) },
        'CONTENT' => sub{ $_[0]->content },
        'SCRIPT' => sub{ '/' },
        'LOCATION' => sub{ '/?' . $_[0]->title },
        'LOCATION-REV' => sub{ '/rev/' . $_[0]->rev },
    );
    my $param = eval $test->{'param'};
    my $got = $liq->execute($test->{'tmpl'}, $param);
    is $got, $test->{'expected'}, $test->{'name'};
}

package Mock::Page;

sub rev     { return shift->{'rev'} }
sub title   { return shift->{'title'} }
sub posted  { return shift->{'posted'} }
sub source  { return shift->{'source'} }
sub content { return shift->{'content'} }

__END__

=== x
--- tmpl
<p>{{x}}</p>
--- param
{'x'=>'foo'}
--- expected
<p>foo</p>

=== x HTML(default)
--- tmpl
<p>{{x}}</p>
--- param
{'x'=>q(&amp;<>"')}
--- expected
<p>&amp;&lt;&gt;&quot;&#39;</p>

=== x HTMLALL
--- tmpl
<p>{{x HTMLALL}}</p>
--- param
{'x'=>q(&amp;<>"')}
--- expected
<p>&amp;amp;&lt;&gt;&quot;&#39;</p>

=== x HTML
--- tmpl
<p>{{x}}</p>
--- param
{'x'=>q(&amp;<>"')}
--- expected
<p>&amp;&lt;&gt;&quot;&#39;</p>

=== x URIALL
--- tmpl
<p>{{x URIALL}}</p>
--- param
{'x'=>q(http://foo/?&amp;<>"'#d)}
--- expected
<p>http%3A//foo/%3F%26amp%3B%3C%3E%22%27%23d</p>

=== x URI
--- tmpl
<p>{{x URI}}</p>
--- param
{'x'=>q(http://foo/?&amp;<>"'#d)}
--- expected
<p>http://foo/?&amp;%3C%3E%22%27#d</p>

=== x k0 k1
--- tmpl
<p>{{x k0 k1}}</p>
--- param
{'x'=>{'k0'=>{'k1'=>'foo'},'k1'=>'bad'}}
--- expected
<p>foo</p>

=== page
--- tmpl
<!DOCTYPE html>
<html>
<head>
<title>{{page title}}</title>
</head>
<body>
<h1><a href="{{page LOCATION}}">{{page title}}</a></h1>
{{page CONTENT}}

<p class="posted"><a href="{{page LOCATION-REV}}">rev. {{page rev}} : {{page posted YMDHM}}</a></p>

<table><tr>
<td><form method="GET" action="{{SCRIPT}}">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="e" />
<input type="hidden" name="q" value="{{page title HTMLALL}}" />
<input type="submit" value=" Edit " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="h" />
<input type="hidden" name="q" value="{{page title HTMLALL}}" />
<input type="submit" value=" History " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>
--- param
{
    'page' => (bless {
        'rev' => 7,
        'title' => 'TestPage',
        'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-03 20:18:32'),
        'source' => 'Hello, World.'."\n",
        'content' => "\n<p>Hello, World.</p>\n",
    }, 'Mock::Page'),
}
--- expected
<!DOCTYPE html>
<html>
<head>
<title>TestPage</title>
</head>
<body>
<h1><a href="/?TestPage">TestPage</a></h1>

<p>Hello, World.</p>

<p class="posted"><a href="/rev/7">rev. 7 : 2013-08-03 20:18</a></p>

<table><tr>
<td><form method="GET" action="/">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="e" />
<input type="hidden" name="q" value="TestPage" />
<input type="submit" value=" Edit " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="h" />
<input type="hidden" name="q" value="TestPage" />
<input type="submit" value=" History " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>

=== edit
--- tmpl
<!DOCTYPE html>
<html>
<head>
<title>Edit {{page title}}</title>
</head>
<body>
<h1>Edit <a href="{{page LOCATION}}">{{page title}}</a></h1>

<form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<div>
<input type="hidden" name="c" value="w" />
<input type="hidden" name="q" value="{{page title HTMLALL}}" />
<textarea name="t" style="width: 100%; height: 20em">{{page source HTMLALL}}</textarea><br />
<input type="submit" value=" Save " />
</div>
</form>

<table><tr>
<td><form method="GET" action="{{SCRIPT}}">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>
--- param
{
    'page' => (bless {
        'rev' => 7,
        'title' => 'TestPage',
        'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-03 20:18:32'),
        'source' => 'Hello, World.'."\n",
    }, 'Mock::Page'),
}
--- expected
<!DOCTYPE html>
<html>
<head>
<title>Edit TestPage</title>
</head>
<body>
<h1>Edit <a href="/?TestPage">TestPage</a></h1>

<form method="POST" action="/" enctype="multipart/form-data">
<div>
<input type="hidden" name="c" value="w" />
<input type="hidden" name="q" value="TestPage" />
<textarea name="t" style="width: 100%; height: 20em">Hello, World.
</textarea><br />
<input type="submit" value=" Save " />
</div>
</form>

<table><tr>
<td><form method="GET" action="/">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>

=== FOR x IN a
--- tmpl
{{FOR.1 x IN a }}
<p>{{x}}</p>
{{ENDFOR.1}}
--- param
{'a'=>['foo','bar','baz']}
--- expected
<p>foo</p>
<p>bar</p>
<p>baz</p>

=== FOR nest
--- tmpl
<table>
{{FOR.1 r IN a }}
<tr>{{FOR.2 x IN r }}<td>{{x}}</td>{{ENDFOR.2}}</tr>
{{ENDFOR.1}}
</table>
--- param
{'a'=>[[qw(a00 a01)],[qw(a10 a11)]]}
--- expected
<table>
<tr><td>a00</td><td>a01</td></tr>
<tr><td>a10</td><td>a11</td></tr>
</table>

=== IF true
--- tmpl
<h1>true</h1>
{{IF.1 x }}
<p>{{x}}</p>
{{ENDIF.1}}
<p>ok</p>
--- param
{'x' => 'foo'}
--- expected
<h1>true</h1>
<p>foo</p>
<p>ok</p>

=== IF false
--- tmpl
<h1>false</h1>
{{IF.1 x }}
<p>{{x}}</p>
{{ENDIF.1}}
<p>ok</p>
--- param
{'x' => ''}
--- expected
<h1>false</h1>
<p>ok</p>

=== IF ELSE true
--- tmpl
<h1>true</h1>
{{IF.1 x }}
<p>{{x}}</p>
{{ELSE.1}}
<p>else</p>
{{ENDIF.1}}
<p>ok</p>
--- param
{'x' => 'foo'}
--- expected
<h1>true</h1>
<p>foo</p>
<p>ok</p>

=== IF ELSE false
--- tmpl
<h1>false</h1>
{{IF.1 x }}
<p>{{x}}</p>
{{ELSE.1}}
<p>else</p>
{{ENDIF.1}}
<p>ok</p>
--- param
{'x' => ''}
--- expected
<h1>false</h1>
<p>else</p>
<p>ok</p>

=== history
--- tmpl
<!DOCTYPE html>
<html>
<head>
<title>History {{list 0 title}}</title>
</head>
<body>
<h1>History <a href="{{list 0 LOCATION}}">{{list 0 title}}</a></h1>

<ul>
{{FOR.1 item IN list}}
<li>{{item posted YMDHM}} <a href="{{item LOCATION-REV}}">rev. {{item rev}}</a></li>
{{ENDFOR.1}}
</ul>

<table><tr>
<td><form method="GET" action="{{SCRIPT}}">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="h" />
<input type="hidden" name="q" value="{{list 0 title HTMLALL}}" />
<input type="submit" value=" History " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>
--- param
{
    'list' => [
        (bless {
            'rev' => 28,
            'title' => 'Foo',
            'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-03 20:18:32'),
            'source' => '',
        }, 'Mock::Page'),
        (bless {
            'rev' => 17,
            'title' => 'Foo',
            'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-02 20:45:02'),
            'source' => '',
        }, 'Mock::Page'),
        (bless {
            'rev' => 11,
            'title' => 'Foo',
            'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-01 21:02:15'),
            'source' => '',
        }, 'Mock::Page'),
    ],
}
--- expected
<!DOCTYPE html>
<html>
<head>
<title>History Foo</title>
</head>
<body>
<h1>History <a href="/?Foo">Foo</a></h1>

<ul>
<li>2013-08-03 20:18 <a href="/rev/28">rev. 28</a></li>
<li>2013-08-02 20:45 <a href="/rev/17">rev. 17</a></li>
<li>2013-08-01 21:02 <a href="/rev/11">rev. 11</a></li>
</ul>

<table><tr>
<td><form method="GET" action="/">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="h" />
<input type="hidden" name="q" value="Foo" />
<input type="submit" value=" History " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>

=== rev
--- tmpl
<!DOCTYPE html>
<html>
<head>
<title>Draft {{page title}} rev. {{page rev}}</title>
</head>
<body>
<header>
<h1>Draft <a href="{{page LOCATION}}">{{page title}}</a> rev. {{page rev}}</h1>
</header>

<div id="source">
{{FOR.1 line IN page source LINES}}
<div class="line">{{line HTMLALL ENSP}}</div>
{{ENDFOR.1}}
</div>

<p class="posted"><a href="{{page LOCATION-REV}}">rev. {{page rev}} : {{page posted YMDHM}}</a>{{IF.1 prev posted}}<br />
<a href="{{prev LOCATION-REV}}">prev : {{prev posted YMDHM}}</a>{{ENDIF.1}}</p>

<table><tr>
<td><form method="GET" action="{{SCRIPT}}">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="E" />
<input type="hidden" name="r" value="{{page rev HTMLALL}}" />
<input type="submit" value=" Edit " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="h" />
<input type="hidden" name="q" value="{{page title HTMLALL}}" />
<input type="submit" value=" History " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>
--- param
{
    'page' => (bless {
        'rev' => 7,
        'title' => 'TestPage',
        'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-03 20:18:32'),
        'source' => "line 1.\n"."  line 2.\n"."\n"."line 3.\n",
    }, 'Mock::Page'),
    'prev' => (bless {
        'rev' => 5,
        'title' => 'TestPage',
        'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-01 20:45:02'),
        'source' => "line 1.\n",
    }, 'Mock::Page'),
}
--- expected
<!DOCTYPE html>
<html>
<head>
<title>Draft TestPage rev. 7</title>
</head>
<body>
<header>
<h1>Draft <a href="/?TestPage">TestPage</a> rev. 7</h1>
</header>

<div id="source">
<div class="line">line&#8194;1.</div>
<div class="line">&#8194;&#8194;line&#8194;2.</div>
<div class="line">&nbsp;</div>
<div class="line">line&#8194;3.</div>
</div>

<p class="posted"><a href="/rev/7">rev. 7 : 2013-08-03 20:18</a><br />
<a href="/rev/5">prev : 2013-08-01 20:45</a></p>

<table><tr>
<td><form method="GET" action="/">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="E" />
<input type="hidden" name="r" value="7" />
<input type="submit" value=" Edit " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="h" />
<input type="hidden" name="q" value="TestPage" />
<input type="submit" value=" History " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>

=== recent
--- tmpl
<!DOCTYPE html>
<html>
<head>
<title>Recent Changes</title>
</head>
<body>
<h1>Recent Changes</h1>

<ul>
{{FOR.1 item IN list }}
<li>{{item posted YMDHM}} <a href="{{item LOCATION}}">{{item title}}</a></li>
{{ENDFOR.1}}
</ul>

<table><tr>
<td><form method="GET" action="{{SCRIPT}}">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="{{SCRIPT}}" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>
--- param
+{
    'list' => [
        (bless {
            'rev' => 28,
            'title' => 'Foo',
            'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-03 20:18:32'),
            'source' => '',
        }, 'Mock::Page'),
        (bless {
            'rev' => 17,
            'title' => 'Bar',
            'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-02 20:45:02'),
            'source' => '',
        }, 'Mock::Page'),
        (bless {
            'rev' => 11,
            'title' => 'Baz',
            'posted' => Lamawiki::Strftime::strftime('%s', '2013-08-01 21:02:15'),
            'source' => '',
        }, 'Mock::Page'),
    ],
};
--- expected
<!DOCTYPE html>
<html>
<head>
<title>Recent Changes</title>
</head>
<body>
<h1>Recent Changes</h1>

<ul>
<li>2013-08-03 20:18 <a href="/?Foo">Foo</a></li>
<li>2013-08-02 20:45 <a href="/?Bar">Bar</a></li>
<li>2013-08-01 21:02 <a href="/?Baz">Baz</a></li>
</ul>

<table><tr>
<td><form method="GET" action="/">
<input type="submit" value=" Top " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="a" />
<input type="submit" value=" All " />
</form></td>
<td><form method="POST" action="/" enctype="multipart/form-data">
<input type="hidden" name="c" value="r" />
<input type="submit" value=" Recent Changes " />
</form></td>
</tr>
</table>
</body>
</html>

