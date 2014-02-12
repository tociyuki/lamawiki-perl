use strict;
use warnings;
use Lamawiki::Liq;
use Lamawiki::Converter;
use Test::More;
use lib qw(./t/lib);
use Lamawikix::Testutil qw(split_spec);

my $blocks = split_spec(qw(@== @--), do{ local $/ = undef; scalar <DATA> });

plan tests => 1 * @{$blocks};

my $converter = Lamawiki::Converter->new({'view' => Lamawiki::Liq->new});

for my $test (@{$blocks}) {
    my $page = Mock::Page->new({'source' => $test->{'input'}});
    my $got = $converter->convert($page)->content;
    is $got, "\n" . $test->{'expected'}, $test->{'name'};
}

{
    package Mock::Page;
    use Encode;
    sub new { return bless {%{$_[1] || +{}}}, ref $_[0] || $_[0] }
    sub source  { return $_[0]{'source'} }
    sub content { return $_[0]{'content'} }
    sub rel     { return $_[0]{'rel'} }
    sub is_title { return 1 }
}

__END__

@== paragraph
@-- input
paragraph 1

paragraph 2a
paragraph 2b
paragraph 2c


paragraph 3a
paragraph 3b
@-- expected
<p>paragraph 1</p>

<p>paragraph 2a
paragraph 2b
paragraph 2c</p>

<p>paragraph 3a
paragraph 3b</p>

@== headings
@-- input
# heading1

## heading2

### heading3

#### heading4

##### heading5

###### heading6

paragraph

# heading1
@-- expected
<nav id="toc">
<ul>
<li><a href="#heading1">heading1</a>
<ul>
<li><a href="#heading2">heading2</a>
<ul>
<li><a href="#heading3">heading3</a>
<ul>
<li><a href="#heading4">heading4</a>
<ul>
<li><a href="#heading5">heading5</a></li>
<li><a href="#heading6">heading6</a></li>
</ul>
</li>
</ul>
</li>
</ul>
</li>
</ul>
</li>
<li><a href="#heading1_2">heading1</a></li>
</ul>
</nav>

<h2 id="heading1">heading1</h2>

<h3 id="heading2">heading2</h3>

<h4 id="heading3">heading3</h4>

<h5 id="heading4">heading4</h5>

<h6 id="heading5">heading5</h6>

<h6 id="heading6">heading6</h6>

<p>paragraph</p>

<h2 id="heading1_2">heading1</h2>


@== headings 2
@-- input
# heading1 ######

## heading2 #####

### heading3 ####

#### heading4 ###

##### heading5 ##

###### heading6 #

paragraph

# heading1
@-- expected
<nav id="toc">
<ul>
<li><a href="#heading1">heading1</a>
<ul>
<li><a href="#heading2">heading2</a>
<ul>
<li><a href="#heading3">heading3</a>
<ul>
<li><a href="#heading4">heading4</a>
<ul>
<li><a href="#heading5">heading5</a></li>
<li><a href="#heading6">heading6</a></li>
</ul>
</li>
</ul>
</li>
</ul>
</li>
</ul>
</li>
<li><a href="#heading1_2">heading1</a></li>
</ul>
</nav>

<h2 id="heading1">heading1</h2>

<h3 id="heading2">heading2</h3>

<h4 id="heading3">heading3</h4>

<h5 id="heading4">heading4</h5>

<h6 id="heading5">heading5</h6>

<h6 id="heading6">heading6</h6>

<p>paragraph</p>

<h2 id="heading1_2">heading1</h2>

@== horizontal rule
@-- input
----

# Horizontal Rule

------

paragraph

----
@-- expected
<nav id="toc">
<ul>
<li><a href="#HorizontalU20URule">Horizontal Rule</a></li>
</ul>
</nav>

<hr />

<h2 id="HorizontalU20URule">Horizontal Rule</h2>

<hr />

<p>paragraph</p>

<hr />

@== verbatim
@-- input
# Verbatim

triple back-ticks. &amp; <escape> {{foo}}.

```
# Verbatim

triple back-ticks. &amp; <escape> {{foo}}.
```

paragraph
@-- expected
<nav id="toc">
<ul>
<li><a href="#Verbatim">Verbatim</a></li>
</ul>
</nav>

<h2 id="Verbatim">Verbatim</h2>

<p>triple back-ticks. &amp; &lt;escape&gt; {{foo}}.</p>

<pre><code># Verbatim

triple back-ticks. &amp;amp; &lt;escape&gt; {{foo}}.</code></pre>

<p>paragraph</p>

@== unordered list tight
@-- input
* item1
* item2
* item3
@-- expected
<ul>
<li>item1</li>
<li>item2</li>
<li>item3</li>
</ul>

@== unordered list loose
@-- input
* item1

* item2

* item3

@-- expected
<ul>
<li>item1</li>
<li>item2</li>
<li>item3</li>
</ul>

@== multiline item
@-- input
*   item1a
    item1b
    item1c

*   item2a
    item2b
@-- expected
<ul>
<li>item1a
item1b
item1c</li>
<li>item2a
item2b</li>
</ul>

@== ordered list tight
@-- input
1. item1
1. item2
1. item3
@-- expected
<ol>
<li>item1</li>
<li>item2</li>
<li>item3</li>
</ol>

@== ordered list loose
@-- input
1. item1

1. item2

1. item3

@-- expected
<ol>
<li>item1</li>
<li>item2</li>
<li>item3</li>
</ol>

@== define list tight
@-- input
? term1
: describe1
: describe2
? term3
? term4
: describe3

paragraph1

: describe
? term

paragraph2
@-- expected
<dl>
<dt>term1</dt>
<dd>describe1</dd>
<dd>describe2</dd>
<dt>term3</dt>
<dt>term4</dt>
<dd>describe3</dd>
</dl>

<p>paragraph1</p>

<dl>
<dd>describe</dd>
<dt>term</dt>
</dl>

<p>paragraph2</p>

@== define list loose
@-- input
? term1

: describe1

: describe2

? term3

? term4

: describe3

paragraph1

: describe

? term

paragraph2
@-- expected
<dl>
<dt>term1</dt>
<dd>describe1</dd>
<dd>describe2</dd>
<dt>term3</dt>
<dt>term4</dt>
<dd>describe3</dd>
</dl>

<p>paragraph1</p>

<dl>
<dd>describe</dd>
<dt>term</dt>
</dl>

<p>paragraph2</p>

@== list seq
@-- input
*  unordered 1
*  unordered 2
1. ordered 1
1. ordered 2
?  term1
:  desc1
@-- expected
<ul>
<li>unordered 1</li>
<li>unordered 2</li>
</ul>

<ol>
<li>ordered 1</li>
<li>ordered 2</li>
</ol>

<dl>
<dt>term1</dt>
<dd>desc1</dd>
</dl>

@== list nesting
@-- input
* item1
  * item1a
  * item1b
* item2
  1. item2a
  1. item2b
* item3
  ? term3a
  : describe3a
  ? term3b
  : describe3b
@-- expected
<ul>
<li>item1
<ul>
<li>item1a</li>
<li>item1b</li>
</ul>
</li>
<li>item2
<ol>
<li>item2a</li>
<li>item2b</li>
</ol>
</li>
<li>item3
<dl>
<dt>term3a</dt>
<dd>describe3a</dd>
<dt>term3b</dt>
<dd>describe3b</dd>
</dl>
</li>
</ul>

@== list nest strange
@-- input
    * item1
 * item2
     * item3
   * item4
* item5
@-- expected
<ul>
<li>item1</li>
<li>item2
<ul>
<li>item3</li>
<li>item4</li>
</ul>
</li>
<li>item5</li>
</ul>

@== blockquote and paragraph
@-- input
>>>
paragraph1

paragraph2
<<<
@-- expected
<blockquote>
<p>paragraph1</p>

<p>paragraph2</p>
</blockquote>

@== blockquote and blockquote
@-- input
>>>
paragraph1

>>>
paragraph2
<<<
<<<
@-- expected
<blockquote>
<p>paragraph1</p>

<blockquote>
<p>paragraph2</p>
</blockquote>
</blockquote>

@== blockquote and heading
@-- input
>>>
# heading1

>>>
paragraph2
<<<

# heading2
<<<
@-- expected
<nav id="toc">
<ul>
<li><a href="#heading1">heading1</a></li>
<li><a href="#heading2">heading2</a></li>
</ul>
</nav>

<blockquote>
<h2 id="heading1">heading1</h2>

<blockquote>
<p>paragraph2</p>
</blockquote>

<h2 id="heading2">heading2</h2>
</blockquote>

@== blockquote and verbatim
@-- input
>>>
```
verbatim1
```

>>>
paragraph2
<<<

```
verbatim2
```
<<<
@-- expected
<blockquote>
<pre><code>verbatim1</code></pre>

<blockquote>
<p>paragraph2</p>
</blockquote>

<pre><code>verbatim2</code></pre>
</blockquote>

@== blockquote and list
@-- input
* item 1
 * item 2

>>>
 * item 3
 * item 4
<<<

 * item 5
* item 6
@-- expected
<ul>
<li>item 1
<ul>
<li>item 2</li>
</ul>
</li>
</ul>

<blockquote>
<ul>
<li>item 3</li>
<li>item 4</li>
</ul>
</blockquote>

<ul>
<li>item 5</li>
<li>item 6</li>
</ul>

@== inline line break
@-- input
two spaces at line end  
produce line break element.
@-- expected
<p>two spaces at line end<br />
produce line break element.</p>

@== escape and inline code
@-- input
backticks produces escape `&<>"'` and `` ` `` or
code elements ``` &<>"' ```.
@-- expected
<p>backticks produces escape &amp;&lt;&gt;&quot;&#39; and ` or
code elements <code>&amp;&lt;&gt;&quot;&#39;</code>.</p>

@== pagetitle link
@-- input
double brackets produces [[LamawikiName]] element.
and [optional text][[LamawikiName]] is available.
@-- expected
<p>double brackets produces <a href="0" title="LamawikiName">LamawikiName</a> element.
and <a href="0" title="LamawikiName">optional text</a> is available.</p>
@-- expected_old
<p>double brackets produces <a href="{{page rel 0 LOCATION}}" title="LamawikiName">LamawikiName</a> element.
and <a href="{{page rel 0 LOCATION}}" title="LamawikiName">optional text</a> is available.</p>

@== pagetitle link and fragment
@-- input
[[#heading1]].

[[page2#heading2]].

# heading1

[[page3#heading3]].
@-- expected
<nav id="toc">
<ul>
<li><a href="#heading1">heading1</a></li>
</ul>
</nav>

<p><a href="#heading1">#heading1</a>.</p>

<p><a href="0#heading2" title="page2">page2#heading2</a>.</p>

<h2 id="heading1">heading1</h2>

<p><a href="1#heading3" title="page3">page3#heading3</a>.</p>
@-- expected_old
<nav id="toc">
<ul>
<li><a href="#heading1">heading1</a></li>
</ul>
</nav>

<p><a href="#heading1">#heading1</a>.</p>

<p><a href="{{page rel 0 LOCATION}}#heading2" title="page2">page2#heading2</a>.</p>

<h2 id="heading1">heading1</h2>

<p><a href="{{page rel 1 LOCATION}}#heading3" title="page3">page3#heading3</a>.</p>

@== em emphasis
@-- input
 1. *a*.
 2. *a **b***.
 3. *a **b** c*.
 4. *a **b** c **d***.
 5. *a **b** c **d** e*.
@-- expected
<ol>
<li><em>a</em>.</li>
<li><em>a <strong>b</strong></em>.</li>
<li><em>a <strong>b</strong> c</em>.</li>
<li><em>a <strong>b</strong> c <strong>d</strong></em>.</li>
<li><em>a <strong>b</strong> c <strong>d</strong> e</em>.</li>
</ol>

@== strong emphasis
@-- input
 1. **a**.
 2. **a *b***.
 3. **a *b* c**.
 4. **a *b* c *d***.
 5. **a *b* c *d* e**.
@-- expected
<ol>
<li><strong>a</strong>.</li>
<li><strong>a <em>b</em></strong>.</li>
<li><strong>a <em>b</em> c</strong>.</li>
<li><strong>a <em>b</em> c <em>d</em></strong>.</li>
<li><strong>a <em>b</em> c <em>d</em> e</strong>.</li>
</ol>

@== strong and em emphasis
@-- input
 1. ***a***.
 2. ***a* b**.
 3. ***a* b *c***.
 4. ***a* b *c* d**.
 5. ***a* b *c* d *e***.
@-- expected
<ol>
<li><strong><em>a</em></strong>.</li>
<li><strong><em>a</em> b</strong>.</li>
<li><strong><em>a</em> b <em>c</em></strong>.</li>
<li><strong><em>a</em> b <em>c</em> d</strong>.</li>
<li><strong><em>a</em> b <em>c</em> d <em>e</em></strong>.</li>
</ol>

@== em and strong emphasis
@-- input
 1. ***a***.
 2. ***a** b*.
 3. ***a** b **c***.
 4. ***a** b **c** d*.
 5. ***a** b **c** d **e***.
@-- expected
<ol>
<li><strong><em>a</em></strong>.</li>
<li><em><strong>a</strong> b</em>.</li>
<li><em><strong>a</strong> b <strong>c</strong></em>.</li>
<li><em><strong>a</strong> b <strong>c</strong> d</em>.</li>
<li><em><strong>a</strong> b <strong>c</strong> d <strong>e</strong></em>.</li>
</ol>

@== space and emphasis
@-- input
 1. a* *b* c** **d** e*** ***f***.
@-- expected
<ol>
<li>a* <em>b</em> c** <strong>d</strong> e*** <strong><em>f</em></strong>.</li>
</ol>

@== asterisks themselves
@-- input
 1. spaced 3 * 4 + 5 * 6 = 42.
 2. spaced 3 ** 2 + 4 ** 2 = 25.
 3. over four are ****not emphasis****.
@-- expected
<ol>
<li>spaced 3 * 4 + 5 * 6 = 42.</li>
<li>spaced 3 ** 2 + 4 ** 2 = 25.</li>
<li>over four are ****not emphasis****.</li>
</ol>

@== reflink
@-- input
[Lamawikipedia japan][1].
[Google][google].
[Google][].

 [1]: http://ja.wikipedia.org/
 [google]: http://www.google.co.jp/
@-- expected
<p><a href="http://ja.wikipedia.org/">Lamawikipedia japan</a>.
<a href="http://www.google.co.jp/">Google</a>.
<a href="http://www.google.co.jp/">Google</a>.</p>

@== inplace link
@-- input
[Lamawikipedia japan](http://ja.wikipedia.org/).
[Google](http://www.google.co.jp/).
[with paren]( http://example.net/foo(bar) ).
@-- expected
<p><a href="http://ja.wikipedia.org/">Lamawikipedia japan</a>.
<a href="http://www.google.co.jp/">Google</a>.
<a href="http://example.net/foo(bar)">with paren</a>.</p>

@== angled inplace link
@-- input
<http://ja.wikipedia.org/>.
<http://www.google.co.jp/>,
<http://example.net/foo(bar).>!
@-- expected
<p><a href="http://ja.wikipedia.org/">http://ja.wikipedia.org/</a>.
<a href="http://www.google.co.jp/">http://www.google.co.jp/</a>,
<a href="http://example.net/foo(bar).">http://example.net/foo(bar).</a>!</p>

@== plain uri
@-- input
http://ja.wikipedia.org/.
http://www.google.co.jp/,
http://example.net/foo(bar).
@-- expected
<p>http://ja.wikipedia.org/.
http://www.google.co.jp/,
http://example.net/foo(bar).</p>

@== footnote
@-- input
foo[^1] bar[^2].

 [^1]: footnote foo.
 [^2]: footnote bar.
@-- expected
<p>foo<a href="#fn1" rel="footnote">1</a> bar<a href="#fn2" rel="footnote">2</a>.</p>

<ol class="footnote">
<li id="fn1">footnote foo.</li>
<li id="fn2">footnote bar.</li>
</ol>

@== commentout
@-- input
-# comment 1
foo
-# comment 2

bar
@-- expected
<p>foo</p>

<p>bar</p>

@== figure image
@-- input
paragraph1

![Example image](http://www.example.net/image/sample.png)

paragraph2
@-- expected
<p>paragraph1</p>

<figure>
<img src="http://www.example.net/image/sample.png" alt="" /><br />
<figcaption>Example image</figcaption>
</figure>

<p>paragraph2</p>

@== figure image in list item
@-- input
paragraph1

* item 1

  ![Example image](http://www.example.net/image/sample.png)

* item 2

paragraph2
@-- expected
<p>paragraph1</p>

<ul>
<li>item 1
<figure>
<img src="http://www.example.net/image/sample.png" alt="" /><br />
<figcaption>Example image</figcaption>
</figure>
</li>
<li>item 2</li>
</ul>

<p>paragraph2</p>

@== include macro
@-- input
paragraph1

![text part][[include:SubPage]]

paragraph2
@-- expected
<p>paragraph1</p>

<div wiki="include:SubPage">text part</div>

<p>paragraph2</p>

@== index macro
@-- input
paragraph1

![text part][[index:Todo]]

paragraph2
@-- expected
<p>paragraph1</p>

<div wiki="index:Todo">text part</div>

<p>paragraph2</p>

@== nav macro
@-- input
paragraph1

![text part][[nav:UpPage]]

paragraph2
@-- expected
<p>paragraph1</p>

<div wiki="nav:UpPage">text part</div>

<p>paragraph2</p>

@== toc macro
@-- input

paragraph1

![text part][[toc:SubPage]]

paragraph2
@-- expected
<p>paragraph1</p>

<div wiki="toc:SubPage">text part</div>

<p>paragraph2</p>

@== toc macro in list
@-- input

# Table of Contents

1.  [[SubPage1]]
    ![text part][[toc:SubPage1]]
2.  [[SubPage2]]
    ![text part][[toc:SubPage2]]

paragraph
@-- expected
<nav id="toc">
<ul>
<li><a href="#TableU20UofU20UContents">Table of Contents</a></li>
</ul>
</nav>

<h2 id="TableU20UofU20UContents">Table of Contents</h2>

<ol>
<li><a href="0" title="SubPage1">SubPage1</a>
<div wiki="toc:SubPage1">text part</div>
</li>
<li><a href="1" title="SubPage2">SubPage2</a>
<div wiki="toc:SubPage2">text part</div>
</li>
</ol>

<p>paragraph</p>
@-- expected_old
<nav id="toc">
<ul>
<li><a href="#TableU20UofU20UContents">Table of Contents</a></li>
</ul>
</nav>

<h2 id="TableU20UofU20UContents">Table of Contents</h2>

<ol>
<li><a href="{{page rel 0 LOCATION}}" title="SubPage1">SubPage1</a>
<div wiki="toc:SubPage1">text part</div>
</li>
<li><a href="{{page rel 1 LOCATION}}" title="SubPage2">SubPage2</a>
<div wiki="toc:SubPage2">text part</div>
</li>
</ol>

<p>paragraph</p>

@== self toc macro
@-- input
![Table of Contents][[toc]]

# Heading1

paragraph1

## Heading2

paragraph2

## Heading3

paragraph3

# Heading4

paragraph4

# Heading5

paragraph5
@-- expected
<nav id="toc">
<ul>
<li><a href="#Heading1">Heading1</a>
<ul>
<li><a href="#Heading2">Heading2</a></li>
<li><a href="#Heading3">Heading3</a></li>
</ul>
</li>
<li><a href="#Heading4">Heading4</a></li>
<li><a href="#Heading5">Heading5</a></li>
</ul>
</nav>

<nav class="toc">
<h1>Table of Contents</h1>

<ul>
<li><a href="#Heading1">Heading1</a>
<ul>
<li><a href="#Heading2">Heading2</a></li>
<li><a href="#Heading3">Heading3</a></li>
</ul>
</li>
<li><a href="#Heading4">Heading4</a></li>
<li><a href="#Heading5">Heading5</a></li>
</ul>
</nav>

<h2 id="Heading1">Heading1</h2>

<p>paragraph1</p>

<h3 id="Heading2">Heading2</h3>

<p>paragraph2</p>

<h3 id="Heading3">Heading3</h3>

<p>paragraph3</p>

<h2 id="Heading4">Heading4</h2>

<p>paragraph4</p>

<h2 id="Heading5">Heading5</h2>

<p>paragraph5</p>

@== self toc macro no heading
@-- input
![Table of Content][[toc]]

paragraph
@-- expected
<p>paragraph</p>

