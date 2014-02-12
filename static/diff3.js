function Diff3() {}

Diff3.__INFO__ = {
    'name': 'diff3-js',
    'description': 'compute difference sets between two or three arrays of string.',
    'version': '0.05',
    'author': 'MIZUTANI Tociyuki',
    'license': 'GNU General Public License Version 2'
};

// range3_list = (new Diff3()).diff3(mytext, origial, yourtext);
//
// the three-way diff based on the GNU diff3.c
// GNU/diffutils/2.7/diff3.c
//    Three way file comparison program (diff3) for Project GNU.
//    Copyright (C) 1988, 1989, 1992, 1993, 1994 Free Software Foundation, Inc.
//    Written by Randy Smith
Diff3.prototype.diff3 = function(text0, text2, text1) {
    var diff3 = [],
        // diff result => [[symbol, a0, a1, b0, b1], ...]
        diff2 = [
            this.diff(text2, text0),    // mytext - original
            this.diff(text2, text1)     // yourtext - original
        ],
        range3 = [null, 0, 0,  0, 0,  0, 0],
        range2,
        text0_length = text0.length,
        text1_length = text1.length,
        i, j, k, a1_j, a1_k, n,
        lo0, hi0, lo1, hi1, lo2, hi2,
        i0, i1, ok0, ok1;

    while (diff2[0].length > 0 || diff2[1].length > 0) {
        // find a continual range in text2[lo2 .. hi2]
        // changed by text0 or by text1.
        //
        //  diff2[0]     222    222222222
        //     text2  ...L!!!!!!!!!!!!!!!!!!!!H...
        //  diff2[1]       222222   22  2222222
        range2 = [[], []];
        i = diff2[0].length == 0 ? 1
          : diff2[1].length == 0 ? 0
          : diff2[0][0][1] <= diff2[1][0][1] ? 0
          : 1;
        j = i;              // [j, k] = [i, i ^ 1]; // [0, 1] or [1, 0]
        k = i ^ 1;
        a1_j = diff2[j][0][2];
        range2[j].push(diff2[j].shift());
        while (diff2[k].length > 0 && diff2[k][0][1] <= a1_j + 1) {
            a1_k = diff2[k][0][2];
            range2[k].push(diff2[k].shift());
            if (a1_j < a1_k) {
                a1_j = a1_k;
                j = k;      // [j, k] = [k, j];
                k = k ^ 1;
            }
        }
        n = range2[j].length;
        lo2 = range2[i][0][1];
        hi2 = range2[j][n - 1][2];
        // take the corresponding ranges
        // in text0[lo0 .. hi0] and in text1[lo1 .. hi1].
        //
        //     text0  ..L!!!!!!!!!!!!!!!!!!!!!!!!!!!!H...
        //  diff2[0]     222    222222222
        //     text2  ...00!1111!000!!00!111111...
        //  diff2[1]       222222   22  2222222
        //     text1       ...L!!!!!!!!!!!!!!!!H...
        n = range2[0].length;
        if (n > 0) {
            lo0 = range2[0][0][3] - range2[0][0][1] + lo2;
            hi0 = range2[0][n - 1][4] - range2[0][n - 1][2] + hi2;
        }
        else {
            lo0 = range3[2] - range3[6] + lo2;
            hi0 = range3[2] - range3[6] + hi2;
        }
        n = range2[1].length;
        if (n > 0) {
            lo1 = range2[1][0][3] - range2[1][0][1] + lo2;
            hi1 = range2[1][n - 1][4] - range2[1][n - 1][2] + hi2;
        }
        else {
            lo1 = range3[4] - range3[6] + lo2;
            hi1 = range3[4] - range3[6] + hi2;
        }
        range3 = [null, lo0,hi0, lo1,hi1, lo2,hi2];
        // detect type of changes.
        if (range2[0].length == 0) {
            range3[0] = '1';
        }
        else if (range2[1].length == 0) {
            range3[0] = '0';
        }
        else if (hi0 - lo0 != hi1 - lo1) {
            range3[0] = 'A';
        }
        else {
            range3[0] = '2';
            for (d = 0, n = hi0 - lo0; d <= n; ++d) {
                i0 = lo0 + d - 1;
                i1 = lo1 + d - 1;
                ok0 = 0 <= i0 && i0 < text0_length;
                ok1 = 0 <= i1 && i1 < text1_length;
                if (ok0 ^ ok1 || (ok0 && text0[i0] != text1[i1])) {
                    range3[0] = 'A';
                    break;
                }
            }
        }
        diff3.push(range3);
    }
    return diff3;
};

// merge_result = (new Diff3()).merge(mytext, origial, yourtext);
Diff3.prototype.merge = function(a, c, b) {
    var t3 = [a, b, c],
        v = {'conflict' : 0, 'body' : []},
        d3 = this.diff3(a, c, b),
        r3, i, j, k, m, n;

    k = 1;
    for (i = 0, n = d3.length; i < n; ++i) {
        r3 = d3[i];
        for (j = k, m = r3[5]; j < m; ++j)
            v.body.push(t3[2][j - 1]);
        if (r3[0] == '0') {
            for (j = r3[1], m = r3[2] + 1; j < m; ++j)
                v.body.push(t3[0][j - 1]);
        }
        else if (r3[0] != 'A') {
            for (j = r3[3], m = r3[4] + 1; j < m; ++j)
                v.body.push(t3[1][j - 1]);
        }
        else {
            this._conflict_range(t3, r3, v);
        }
        k = r3[6] + 1;
    }
    for (j = k, m = t3[2].length + 1; j < m; ++j)
        v.body.push(t3[2][j - 1]);
    return v;
};

Diff3.prototype._conflict_range = function(t3, r3, v) {
    var t2 = [[], []], h = false, d2, r2, i, j, k, m, n;

    for (i = 0, j = r3[3], m = r3[4] + 1; j < m; ++i, ++j)
        t2[0][i] = t3[1][j - 1];
    for (i = 0, j = r3[1], m = r3[2] + 1; j < m; ++i, ++j)
        t2[1][i] = t3[0][j - 1];
    d2 = this.diff(t2[0], t2[1]);
    for (i = 0, n = d2.length; i < n; ++i) {
        if (d2[i][0] == 'c') {
            h = true;
            break;
        }
    }
    if (h && r3[5] <= r3[6]) {
        ++v.conflict;
        v.body.push('<<<<<<<');
        for (j = r3[1], m = r3[2] + 1; j < m; ++j)
            v.body.push(t3[0][j - 1]);
        v.body.push('|||||||');
        for (j = r3[5], m = r3[6] + 1; j < m; ++j)
            v.body.push(t3[2][j - 1]);
        v.body.push('=======');
        for (j = r3[3], m = r3[4] + 1; j < m; ++j)
            v.body.push(t3[1][j - 1]);
        v.body.push('>>>>>>>');
        return;
    }
    k = 1;
    for (i = 0, n = d2.length; i < n; ++i) {
        r2 = d2[i];
        for (j = k, n = r2[1]; j < n; ++j)
            v.body.push(t2[0][j - 1]);
        if (r2[0] == 'c') {
            ++v.conflict;
            v.body.push('<<<<<<<');
            for (j = r2[3], m = r2[4] + 1; j < m; ++j)
                v.body.push(t2[1][j - 1]);
            v.body.push('=======');
            for (j = r2[1], m = r2[2] + 1; j < m; ++j)
                v.body.push(t2[0][j - 1]);
            v.body.push('>>>>>>>');
        }
        else if (r2[0] == 'a') {
            for (j = r2[3], m = r2[4] + 1; j < m; ++j)
                v.body.push(t2[1][j - 1]);
        }
        k = r2[2] + 1;
    }
    for (j = k, m = t2[0].length + 1; j < m; ++j)
        v.body.push(t2[0][j - 1]);
};

// range2_list = (new Diff3()).diff(original, mytext);
//
// the two-way diff based on the algorithm by P. Heckel.
//     P. Heckel. ``A technique for isolating differences between files.''
//     Communications of the ACM, Vol. 21, No. 4, page 264, April 1978.
Diff3.prototype.diff = function(a, b) {
    var diffs = [], uniqs,
        a_length = a.length, b_length = b.length,
        a0 = 0, a1 = 0, b0 = 0, b1 = 0, a_uniq, b_uniq,
        i, n;

    uniqs = this._build_uniq_index(a, b, [[a_length, b_length]]);
    uniqs.sort(function(u, v){ return u[0] - v[0] });
    while (a1 < a_length && b1 < b_length && a[a1] == b[b1]) {
        ++a1;
        ++b1;
    }
    for (i = 0, n = uniqs.length; i < n; ++i) {
        a_uniq = uniqs[i][0];
        b_uniq = uniqs[i][1];
        if (a_uniq < a1 || b_uniq < b1)
            continue;
        a0 = a1;
        b0 = b1;
        a1 = a_uniq - 1;
        b1 = b_uniq - 1;
        while (a0 <= a1 && b0 <= b1 && a[a1] == b[b1]) {
            --a1;
            --b1;
        }
        if (a0 <= a1 && b0 <= b1) {
            diffs.push(['c', a0 + 1, a1 + 1, b0 + 1, b1 + 1]);
        }
        else if (a0 <= a1) {
            diffs.push(['d', a0 + 1, a1 + 1, b0 + 1, b0]);
        }
        else if (b0 <= b1) {
            diffs.push(['a', a0 + 1, a0, b0 + 1, b1 + 1]);
        }
        a1 = a_uniq + 1;
        b1 = b_uniq + 1;
        while (a1 < a_length && b1 < b_length && a[a1] == b[b1]) {
            ++a1;
            ++b1;
        }
    }
    return diffs;
};

Diff3.prototype.diff_to_html = function(a, b, d) {
    var t = '', i, j, k, n, m, r;

    i = 1;
    for (k = 0, m = d.length; k < m; ++k) {
        r = d[k];
        for (j = i, n = r[3]; j < n; ++j)
            t += '<div class="line">' + this.escape_html(b[j - 1]) + '</div>\n';
        if (r[0] != 'd') {
            for (j = r[3], n = r[4] + 1; j < n; ++j)
                t += '<div class="ins"><ins>' + this.escape_html(b[j - 1]) + '</ins></div>\n';
        }
        if (r[0] != 'a') {
            for (j = r[1], n = r[2] + 1; j < n; ++j)
                t += '<div class="del"><del>' + this.escape_html(a[j - 1]) + '</del></div>\n';
        }
        i = r[4] + 1;
    }
    for (j = i, n = b.length + 1; j < n; ++j)
        t += '<div class="line">' + this.escape_html(b[j - 1]) + '</div>\n';
    return t;
}

Diff3.prototype.escape_html = function(s) {
	if (s == '') {
		return '&nbsp;';
	}
	s = '' + s;
	return s.replace(/[\&<>"'\\ ]/g, function(s1) {
		switch(s1) {
		case '&': return '&amp;';
		case '<': return '&lt;';
		case '>': return '&gt;';
		case '"': return '&quot;';
		case "'": return '&#39;';
		case "\\": return '&#92;';
		case ' ': return '&#8194;'; // &ensp;
		default: return s1;
		}
	});
};

// A. V. Aho, R. Sethi, and J. D. Ullman 'Compilers', p. 530, ISBN4-7819-0586-2
Diff3.prototype.hash_pwj = function(s) {
    var h = 0, g, i, n;

    for (i = 0, n = s.length; i < n; ++i) {
        h = (((h << 4) & 0xffffffff) + s.charCodeAt(i)) & 0xffffffff;
        if (g = h & 0xf0000000) {
            h = (h ^ (g >> 24)) & 0xffffffff;
            h = (h ^ g) & 0xffffffff;
        }
    }
    return h % 499;
};

Diff3.prototype._build_uniq_index = function(a, b, uniqs) {
    var freq = {}, i, j, n, s, h, w;

    for (i = 0, n = a.length; i < n; ++i) {
        s = a[i];
        h = this.hash_pwj(s);
        j = 0;
        while (1) {
            w = '' + h + ',' + j;
            if (typeof freq[w] == 'undefined') {
                freq[w] = {'ax': i, 'bx': -1, 'count': 0};
                break;
            }
            if (a[freq[w].ax] == s) {
                break;
            }
            ++j;
        }
        freq[w].count += 2;
    }
    for (i = 0, n = b.length; i < n; ++i) {
        s = b[i];
        h = this.hash_pwj(s);
        j = 0;
        while (1) {
            w = '' + h + ',' + j;
            if (typeof freq[w] == 'undefined') {
                freq[w] = {'ax': -1, 'bx': i, 'count': 0};
                break;
            }
            if (freq[w].ax >= 0 && a[freq[w].ax] == s) {
                freq[w].bx = i;
                break;
            }
            if (b[freq[w].bx] == s) {
                break;
            }
            ++j;
        }
        freq[w].count += 3;
    }
    for (w in freq) {
        if (freq[w].count == 5)
            uniqs.push([freq[w].ax, freq[w].bx]);
    }
    return uniqs;
};

// change log
//
// 0.05: Tue Nov  5 05:23:53 2013 UTC
//   change: diff_to_html: wiki-like output.
//   change: escape_html replaces ' ' to '&#8194;' (&ensp;) also.
//   add: merge.
// 0.04: Thu Feb  3 06:11:05 2011 UTC
//   add comments
//   better readability.
// 0.03: Wed Feb  2 00:36:47 2011 +09:00 (JST)
//   alpha version 0.03
//   change: make class.
//   add: diff3.
// 0.02: Sun Jul  9 12:50:24 2006 +09:00 (JST)
//   alpha version 0.02
//   change: use a hash function
// 0.01: Sun Jul  9 10:27:21 2006 +09:00 (JST)
//   alpha version 0.01
//   add sprtdiffHTML(a, b, d)
// 0.00: Sun Jul  8 23:40:15 2006 +09:00 (JST)
//   alpha version 0.00

