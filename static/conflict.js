(function (){
    var get_textarea_value = function(id) {
        var s = document.getElementById(id).value;
        if (s.length > 0 && s.charAt(s.length - 1) != '\n')
            s += '\n';
        return s.split('\n');
    };
    var merge_textarea = function() {
        var dh = new Diff3();
        var a = get_textarea_value('mine-text');
        var c = get_textarea_value('orig-text');
        var b = get_textarea_value('your-text');
        var r = dh.merge(a, c, b);
        document.getElementById('your-text').value = r.body.join('\n');
        document.getElementById('conflict-mine-source').style.display = 'none';
        document.getElementById('conflict-orig-source').style.display = 'none';
        document.getElementById('conflict-your-source').style.display = 'none';
        if (r.conflict == 0) {
            document.getElementById('conflict-merge').style.display = 'block';
        }
        else {
            document.getElementById('conflict-fail').style.display = 'block';
        }
        document.getElementById('conflict-marker').style.display = 'block';
    };
    window.onload = merge_textarea;
})();

