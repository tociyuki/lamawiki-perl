(function (){
    var count_diff_info = function(d) {
        var nins = 0, ndel = 0, k, m, r;
        for (k = 0, m = d.length; k < m; ++k) {
            r = d[k];
            if (r[0] != 'd')
                nins += r[4] - r[3] + 1;
            if (r[0] != 'a')
                ndel += r[2] - r[1] + 1;
        }
        return [nins, ndel];
    };
    var get_textarea_value = function(id) {
        var s = document.getElementById(id).value;
        if (s.length > 0 && s.charAt(s.length - 1) != '\n')
            s += '\n';
        return s.split('\n');
    };
    var diff_rev = function() {
        var dh = new Diff3();
        var a = get_textarea_value('prev-text');
        var b = get_textarea_value('page-text');
        var d = dh.diff(a, b);
        var bar = ['diff-bar0', 'diff-bar1', 'diff-bar2', 'diff-bar3', 'diff-bar4'];
        var c = count_diff_info(d);
        var g = c[0] >= 100 ? 3 : c[0] >= 10 ? 2 : c[0] > 0 ? 1 : 0;
        var r = c[1] >= 10 ? 2 : c[1] > 0 ? 1 : 0;
        var i = 0;
        for (; g > 0; --g)
            document.getElementById(bar[i++]).style.color = '#00bb00';
        for (; r > 0; --r)
            document.getElementById(bar[i++]).style.color = '#ff0000';
        document.getElementById('diff-nins').innerHTML = '' + c[0];
        document.getElementById('diff-ndel').innerHTML = '' + c[1];
        document.getElementById('source').innerHTML = dh.diff_to_html(a, b, d);
        document.getElementById('diff-info').style.display = 'block';
    };
    window.onload = diff_rev;
})();

