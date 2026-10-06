import sys, re
from html.parser import HTMLParser
BLOCK={'p','div','li','tr','h1','h2','h3','h4','h5','h6','section','article','header','footer','table','br','figcaption','caption','dt','dd','button','td','th','summary','details','nav','aside'}
class P(HTMLParser):
    def __init__(s):
        super().__init__(); s.out=[]; s.skip=0
    def handle_starttag(s,t,a):
        if t in('script','style','svg'): s.skip+=1
        if t in BLOCK: s.out.append('\n')
        if t in('h1','h2','h3','h4'): s.out.append('#'*int(t[1])+' ')
        if t in('td','th'): s.out.append(' | ')
    def handle_endtag(s,t):
        if t in('script','style','svg'): s.skip-=1
        if t in BLOCK: s.out.append('\n')
    def handle_data(s,d):
        if not s.skip: s.out.append(d)
p=P(); p.feed(open(sys.argv[1]).read())
t=''.join(p.out)
t=re.sub(r'[ \t]+',' ',t); t=re.sub(r'\n\s*\n+','\n',t)
print(t)
