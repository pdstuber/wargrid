import sys

HOOK = """<script>
function _rep(m){try{fetch('/result',{method:'POST',body:'JSERR '+m})}catch(e){}}
window.addEventListener('error',e=>_rep(String(e.message)+' '+(e.error&&e.error.stack||'')));
window.addEventListener('unhandledrejection',e=>_rep('REJ '+String(e.reason)+' '+(e.reason&&e.reason.stack||'')));
</script>
"""

path = sys.argv[1]
text = open(path).read()
if "function _rep(" not in text:
    assert "</head>" in text, "no </head> in " + path
    text = text.replace("</head>", HOOK + "</head>", 1)
    open(path, "w").write(text)
