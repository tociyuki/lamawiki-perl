## Lamawiki version 0.01

Lamawiki は Perl5 で記述した Wiki エンジンです。
CGI スクリプト兼 PSGI アプリケーションとして働きます。
ユーザ認証に htpasswd MD5 形式のパスワード・ファイルを使います。
データベースに SQLite3 を利用します。

各々の Wiki ページをタイトルで識別する、
Wiki の一般的なデータモデルを採用しています。
タイトルの名前空間は単一でフラットです。
タイトルに整数型の識別子が紐付けてあり、
識別子を Wiki ページのパーマリンクに使います。

ユーザが投稿した原稿は、 逐一データベースに蓄積されていきます。
データベースへの保管は、 平文のままで差分や圧縮を伴いません。
そのため、原稿閲覧を低負荷で高速におこなえる反面、
データベース・ファイルのサイズ増大をひきおこす欠点をもちます。
原稿の削除は、 ページごとの最新原稿だけに限定しています。
編集履歴中の古いものや中抜きをすることはできません。

ページと原稿の閲覧は完全にオープンで、 
制限したいときは、 関連するリソース含めて httpd レベルでおこなうことを想定しています。
他方、原稿の書き込みには認可機能が働き、 認証済みユーザを優遇します。
認可機能は、ユーザに与える権限と、
ページ・タイトルをパターンマッチングで仕分けた区分の組み合わせに対して、
書き込み操作を許可します。
認証済みなら、許可を得たページへの書き込みを無制限におこなえます。
認証なしの匿名書き込みを簡単な設定で禁止することができますし、
許可するにしても、幾重の制限を施すことが可能です。
書き込み頻度による制限、
ホワイトリストを用いた原稿中 URI の制限、
ページの最初の原稿書き込みの制限、
管理者長期不在時の匿名書き込み締め出しをおこなえます。

このエンジンの得意分野になると良いと考えているのは、
長文で何ページにも渡るテキストを少数の執筆者陣がサインインして執筆する、
といったものです。 
原稿蓄積の仕組み上、 大勢が協働で事典を作るような目的には向いていません。

## インストール

まず、 PSGI アプリケーションとして動かし、 Plack で動作確認する手順を説明します。
Perl-5.8.9 以上と、 CPAN モジュールの Plack、 cpanm がインストール済みと仮定します。

`Crypt::OpenSSL::Random` が既に利用可能ならそれを使います。

    $ perldoc -ml Crypt::OpenSSL::Random

-または-

`Crypt::URandom` を使うことも可能です。 
新規インストールするなら、 `Crypt::URandom` の方が楽な場合が多いでしょう。

    $ cpanm Crypt::URandom

それ以外に必要なモジュールをインストールします。

    $ cpanm DBI
    $ cpanm DBD::SQLite

これで、テストを走らせることができます。

    $ prove -l t/*.t

動作確認用に `webmaster` ユーザの MD5 パスワードをセットします。

    $ htpasswd -cm data/wikipasswd webmaster

Lamawiki を起動します。

    $ plackup wiki.cgi

ブラウザから `webmaster` ユーザでサインインします。

    $ firefox http://localhost:5000/signin

サインインできると、 空のトップ・ページにリダイレクトします。
編集などをおこなって、 動作を確認してください。

Ubuntu Linux で CGI として動かす良くない例として、
`/var/www/lama` が `+ExecCGI` であるとします。

    $ sudo apt-get install libcrypt-openssl-random-perl
    $ sudo apt-get install libdbi-perl libdbd-sqlite3-perl
    $ sudo cp -r wiki.cgi lib data view static /var/www/lama
    $ pushd /var/www/lama
    $ sudo htpasswd -cm data/wikipasswd webmaster
    $ sudo chown www-data:www-data data wiki.cgi
    $ sudo chmod 544 wiki.cgi

ブラウザから `webmaster` ユーザでサインインします。

    $ firefox http://localhost/lama/wiki.cgi/signin

## 設定

wiki.cgi でおこないます。 同ソース中の `$CONFIG` の コメントを参照してください。

## 原稿書式

書式は独自のもので、 Markdown を意識して定めたものです。

サマリーを示します。
詳細は `t/13.converter.t`、 `21.ctl-layout.t` と `t/data/layout.yml` を参考にしてください。
InterWikiName の記述例は、 `t/data/interwiki.yml` を参考にしてください。

### ブロック

ブロック要素は、 Wiki の書式を Markdown 風にアレンジしたもので、
Markdown とは字面を似せてはいますが、 インデントの扱いが異なり、似て非なるものです。

 * ブロックの区切りは、 空行および空白文字だけの行です。
 * コメントは、 行頭が ``` -# ``` で始まる行です。 書式変換の前にソースから除去します。
 * ヘッディングは、 行頭が ``` # ``` の列で始まる行です。
 * 段落は、 他のブロックにならない空白でない文字で始まる連続行です。
 * 水平区切りは、 4つ以上のハイフンだけ ``` ---- ``` からなる行です。
 * 逐語ブロックは、 3つのバック・クォート ```` ``` ```` の行で挟みます。
    Markdown のタブによるコード・ブロックは使えません。
 * 順序なしリストは、 ``` * ```、 空白で始まる連続行です。
 * 順序リストは、 ``` 1. ```、 空白のように数字列とピリオドで始まる連続行です。
 * 定義リストは、 ``` ? ```、 空白、 および ``` : ```、 空白で始まる連続行です。
    それぞれ、 項目 (``` <dt></dt> ```)、 および記述 (``` <dd></dd> ```) を表します。
 * 3 種類のリストは相互に入れ子にできます。
    入れ子のレベルは行頭のインデントの相対深さ関係で決まります。
 * 引用は、 ``` >>> ``` と ``` <<< ``` の行で挟みます。 入れ子にできます。
 * 図版は、 ``` ![テキスト](URI) ``` からなる行です。
    ``` <figure></figure> ``` ブロックに必ずなります。 インライン・イメージは使えません。
 * レイアウトは、 ``` ![テキスト][[レイアウト名:パラメータ]] ``` からなる行です。

### レイアウト

レイアウトは、 閲覧ページ中に他のページの情報を埋め込むために使います。
他の Wiki エンジンでプラグインやマクロになっている機能を使えるようにしてあります。

 * ``` ![目次][[toc]] ``` は、 ページ内のヘッディングへの目次を展開します。
 * ``` ![][[toc:タイトル]] ``` は、 タイトルで示すページの目次を展開します。
 * ``` ![][[include:タイトル]] ``` は、 タイトルで示すページ内容を展開します。
 * ``` ![][[nav:親タイトル]] ``` は、 親タイトルを利用して、 前後ページへのリンクを展開します。
 * ``` ![][[referer]] ``` は、 現ページを内部リンクで参照しているページをリストアップして展開します。
 * ``` ![][[referer:タイトル]] ``` は、 タイトルのページを内部リンクで参照しているページをリストアップして展開します。
 * ``` ![][[index:前置詞]] ``` は、 前置詞で始まるタイトルがついたページをリストアップして展開します。

### インライン

インライン要素は Markdown のサブセットにしてあります。

 * エスケープするには、 `` `バック・クォート列で囲みます` ``。
   囲みのバック・クォートが 3 個以上のとき、 コード (``` <code></code> ```) にします。
 * 改行するには、 行末に空白を 2 個入れます。
 * 強調するには、 アスタリスク ``` *emphasis* ``` および ``` **strong** ``` で囲みます。
 * 内部リンクは、 ``` [[ページのタイトル]] ``` または ``` [テキスト][[ページのタイトル]] ``` とします。 
   ページ内のヘッディングへフラグメント ``` [[#ヘッディング]] ``` でリンクできます。
 * 脚注へは、 ``` [^識別名] ``` でリンクします。
   脚注は ``` [^識別名]: ``` で始まる連続行です。
 * リファレンス・スタイルのリンクは、 ``` [テキスト][識別名] ``` で作れます。
   リファレンスは ``` [識別名]: URI ``` 形式の行です。
   Markdown と異なり title 属性を使うことはできません。
 * インプレース・スタイルのリンクは、 ``` [テキスト](URI) ``` で作れます。
   Markdown と異なり title 属性を使うことはできません。
 * アングル・リンクは、 ``` <URI> ``` で作れます。

URI は `http:`、 `https:`、 `ftp:`、 `ftps:` 専用でドメインが必須です、
他のスキームを使うとリンクにしませんし、 ドメインなしのリンクも作れません。

## テンプレート

ウェブ・ページの生成に使うテンプレートは、 Liquid テンプレートを原始的にしたものです。

    ./view/ja/

ディレクトリに配置しています。

テンプレートの展開子は、 ``` {{ ダブル・ブレース }} ``` で囲みます。
3種類の展開子を使えます。
展開子の記述では、 英大文字・小文字を区別します。

 * ``` {{ パラメータ展開 }} ``` 形式
 * ``` {{IF.1 パラメータ・リスト }}then部{{ELSE.1}}else部{{ENDIF.1}} ``` 形式
 * ``` {{FOR.1 変数 IN パラメータ・リスト }}each部{{ENDFOR.1}} ``` 形式

パラメータ展開形式は、 スペースで区切った語のパラメータ・リストにしたがい値を展開します。
語を、 インスタンスのメソッド名、
ハッシュのキーか、配列の添字として、データ構造の内側へ潜っていきます。
語はまた、フィルタの名前でもあり、 フィルタを優先して適用します。
コーディング規則では、 フィルタ名に大文字、 キーに小文字を使っています。
パラメータ展開リストの最後がフィルタ名でないときは、 
デフォルトの HTML フィルタを必ず適用します。
なお、 フィルタへ追加パラメータを渡すことはできません。

    <a href="{{page LOCATION}}">{{page title}}</a>

この場合、 ひとつめでは、 page に LOCATION フィルタを適用した結果を展開します。
ふたつめでは、 page の title を得て、 デフォルトの HTML フィルタを適用した結果を展開します。

IF 形式ではパラメータから値を求め、 真のとき then 部を、 偽のとき else 部を展開します。
else 部は省略可能です。 
FOR 形式ではパラメータからリストを求め、ひとつづつ変数を束縛しつつeach部を展開していきます。
変数の束縛は局所的です。

IF 形式と FOR 形式では、 ピリオドに続けて、 必ずラベルを記入しなければなりません。
ネストさせるときは、 ラベルで対応関係を区別します。
ラベルは英数字で1文字以上なら良いのですが、
Lamawiki ではそれぞれの形式のネストレベルを数字で書いています。

    {{IF.1 foo }}foo {{IF.2 bar }}and bar{{ENDIF.2}}{{ENDIF.1}}
    {{IF.1 baz }}baz{{ENDIF.1}}

上の foo と baz のように、 同じネスト・レベルなら、 同じラベルを何度使ってもかまいません。

## DEPENDENCES

 1. Crypt::OpenSSL::Random -or- Crypt::URandom
 2. DBI
 3. DBD::SQLite
 4. Digest::MD5 (core module)
 5. File::Spec (core module)
 6. Encode (core module)
 7. Time::Local (core module)
 8. Test::More (core module)

## COPYRIGHT AND LICENCE

Copyright (C) 2014, MIZUTANI Tociyuki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

