from tokens import LIGHT, DARK

PAGE_CSS = """
@import url('https://fonts.googleapis.com/css2?family=Instrument+Sans:wght@400;500;600;700&display=swap');
:root{color-scheme:light;--page:#EDF4F8;--paper:#FFFFFF;--ink:#25272A;--quiet:#5B5F66;--line:#DDDFE2;--accent:#205F83;--onaccent:#FFFFFF;--wash:#F0F1F2}
html[data-page=dark]{color-scheme:dark;--page:#17181A;--paper:#202124;--ink:#F2F3F5;--quiet:#B9BCC2;--line:#3B3E43;--accent:#98C5E8;--onaccent:#101112;--wash:#26282B}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--page);color:var(--ink);font:15px/1.6 'Instrument Sans',Arial,sans-serif;overflow-x:hidden}
button,input,textarea,select{font:inherit;color:inherit}
a{color:var(--accent);text-underline-offset:3px}
:focus-visible{outline:3px solid var(--accent);outline-offset:3px}
main{max-width:1440px;margin:0 auto;padding:28px 36px 64px}
h1,h2,h3,h4,h5,p,figure{margin:0}
p{max-width:74ch}
.masthead{display:grid;grid-template-columns:minmax(0,1.25fr) minmax(0,1fr);gap:40px;align-items:end;padding:26px 0 30px;border-bottom:2px solid var(--line)}
.masthead h1{font-size:clamp(40px,5vw,64px);line-height:1.04;letter-spacing:-1.8px;font-weight:600}
.masthead h1 span{display:block;color:var(--quiet);font-weight:500}
.masthead p{font-size:17px;margin-top:18px}
.controlbox{background:var(--paper);border:1px solid var(--line);border-radius:14px;padding:18px 20px;display:grid;gap:14px}
.controlbox .ctl{display:flex;justify-content:space-between;align-items:center;gap:14px;flex-wrap:wrap}
.controlbox .ctl b{font-size:14px;font-weight:600}
.controlbox .ctl small{display:block;color:var(--quiet);font-size:12px;font-weight:400}
.toggle-group{display:inline-flex;border:1px solid var(--accent);border-radius:9px;overflow:hidden}
.toggle-group button{border:0;background:transparent;padding:8px 14px;font-size:13px;cursor:pointer;min-width:66px}
.toggle-group button[aria-pressed=true]{background:var(--accent);color:var(--onaccent);font-weight:600}
.toc{display:flex;flex-wrap:wrap;gap:8px 18px;margin:20px 0 0;font-size:14px}
.toc a{color:var(--ink)}
.snapshot{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px;margin-top:26px;font-size:13px}
.snapshot div{border-top:1px solid var(--line);padding-top:12px}
.snapshot b{display:block;font-size:14px;margin-bottom:6px}
.area{margin-top:64px;padding-top:28px;border-top:2px solid var(--line)}
.area>header{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:32px;align-items:end;margin-bottom:8px}
.area h2{font-size:36px;line-height:1.15;letter-spacing:-.8px;font-weight:600}
.area>header p{font-size:14px;color:var(--quiet)}
.group{margin-top:34px}
.group>h3{font-size:21px;font-weight:600;letter-spacing:-.3px}
.group>p{font-size:13px;color:var(--quiet);margin-top:6px}
.frames{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:40px 24px;margin-top:22px;align-items:start}
.frames>figure{min-width:0;display:flex;flex-direction:column;align-items:center}
figcaption{font-size:12px;line-height:1.55;color:var(--quiet);margin-top:14px;max-width:320px;width:100%}
figcaption b{display:block;color:var(--ink);font-size:13px;font-weight:600;margin-bottom:3px}
figcaption code{font-size:11px;color:var(--quiet);font-family:'Instrument Sans',Arial,sans-serif;font-style:italic;overflow-wrap:anywhere}
.wide{margin-top:26px}
.wide figcaption{max-width:880px}
.pairs{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:44px 30px;margin-top:22px}
.pair{min-width:0}
.pair>h4{font-size:15px;font-weight:600;margin-bottom:12px}
.pair .two{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
.pair .two>div{min-width:0}
.pair .two>div>small{display:block;text-align:center;font-size:12px;color:var(--quiet);margin-bottom:6px}
.pair .phone{transform-origin:top left}
.inventory-wrap{max-height:620px;overflow:auto;border:1px solid var(--line);border-radius:12px;background:var(--paper);margin-top:18px}
table.inv{width:100%;border-collapse:collapse;font-size:12px}
table.inv th{position:sticky;top:0;background:var(--wash);text-align:left;font-weight:600;padding:9px 12px;border-bottom:1px solid var(--line);z-index:1}
table.inv td{padding:7px 12px;border-bottom:1px solid var(--line);vertical-align:top;overflow-wrap:break-word}
table.inv td:nth-child(3){color:var(--quiet);font-size:11px;max-width:340px;overflow-wrap:anywhere}
table.inv tr.nd td{color:var(--quiet)}
table.inv tr.areahead td{background:var(--wash);font-weight:600;color:var(--ink)}
.counts{display:flex;flex-wrap:wrap;gap:10px 26px;margin-top:16px;font-size:14px}
.counts b{font-size:22px;font-weight:600;margin-right:6px}
.appendix-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px 36px;margin-top:20px}
.appendix-grid>section{min-width:0}
.appendix-grid h3{font-size:19px;font-weight:600;margin-bottom:10px}
table.tok{width:100%;border-collapse:collapse;font-size:12px}
table.tok td,table.tok th{padding:6px 8px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
table.tok th{font-weight:600}
.swatch{display:inline-block;width:15px;height:15px;border-radius:4px;border:1px solid var(--quiet);vertical-align:-3px;margin-right:6px}
.scale div{display:flex;align-items:baseline;gap:16px;border-bottom:1px solid var(--line);padding:6px 0}
.scale span{width:60px;color:var(--quiet);font-size:12px;flex-shrink:0}
.complist{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px;margin-top:20px}
.complist>div{min-width:0}
.complist>div>h4{font-size:14px;font-weight:600;margin-bottom:8px}
.complist>div>p{font-size:12px;color:var(--quiet);margin-top:8px}
.specimen{border-radius:12px;padding:14px;border:1px solid var(--line)}
.app.specimen{border-color:var(--edge)}
.feedback{margin-top:22px}
.fbgrid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}
.fbgrid label{display:block;background:var(--paper);border:1px solid var(--line);border-radius:10px;padding:12px 14px;font-size:13px;font-weight:600}
.fbgrid textarea,#fb-out,#fb-overall{display:block;width:100%;min-height:74px;margin-top:8px;border:1px solid var(--line);border-bottom:2px solid var(--accent);border-radius:7px;background:var(--page);padding:8px 10px;font-size:13px;font-weight:400;resize:vertical}
#fb-overall{min-height:96px}
.fbactions{display:flex;gap:16px;align-items:center;margin-top:16px;flex-wrap:wrap}
.fbactions button{background:var(--accent);color:var(--onaccent);border:0;border-radius:9px;padding:10px 18px;font-weight:600;cursor:pointer}
.fbactions small{color:var(--quiet);font-size:12px}
#fb-out{min-height:220px;margin-top:14px}
.footer{margin-top:40px;padding-top:16px;border-top:1px solid var(--line);font-size:12px;color:var(--quiet)}
.notes{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px 36px;margin-top:18px;font-size:13px}
.notes div{border-top:1px solid var(--line);padding-top:10px}
.notes b{display:block;margin-bottom:4px}
@media(max-width:1250px){.pairs{grid-template-columns:repeat(2,minmax(0,1fr))}.complist{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:1000px){main{padding:24px 24px 50px}.masthead,.area>header{grid-template-columns:1fr;gap:18px}.snapshot{grid-template-columns:1fr 1fr}.fbgrid{grid-template-columns:1fr 1fr}.appendix-grid{grid-template-columns:1fr}.notes{grid-template-columns:1fr}}
@media(max-width:760px){main{padding:20px 16px 40px}.pairs,.complist,.fbgrid,.snapshot{grid-template-columns:1fr}.frames{grid-template-columns:1fr}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
"""

APP_CSS = (
    ".app{" + LIGHT + "}"
    "html[data-app=dark] .app:not(.force-light),.app.force-dark{" + DARK + "}"
    """
.app{color:var(--text);background:var(--base);font-family:'Instrument Sans',Arial,sans-serif;font-variant-numeric:tabular-nums;font-size:12px;line-height:1.4;text-align:left}
.app *{min-width:0}
.app .vd{display:none}
html[data-app=dark] .app:not(.force-light) .vl,.app.force-dark .vl{display:none}
html[data-app=dark] .app:not(.force-light) .vd,.app.force-dark .vd{display:contents}
.app svg.i{width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;flex-shrink:0;display:block}
.app svg.i.s{width:14px;height:14px}
.app svg.i.l{width:22px;height:22px}
.phone{width:320px;height:760px;border:5px solid var(--bezel);border-radius:38px;overflow:hidden;display:flex;flex-direction:column;position:relative;flex-shrink:0}
.phone.long{height:auto;min-height:760px}
.phone.compact{height:560px}
.st{height:34px;flex-shrink:0;display:flex;justify-content:space-between;align-items:center;padding:4px 20px 0;font-size:10px;font-weight:600;background:var(--base);position:relative}
.st:before{content:'';position:absolute;left:50%;top:7px;width:72px;height:18px;border-radius:12px;background:var(--text);transform:translateX(-50%)}
html[data-app=dark] .app:not(.force-light) .st:before,.app.force-dark .st:before{background:#000}
.pb{flex:1;overflow:hidden;padding:12px 14px 14px;position:relative}
.long .pb{overflow:visible}
.tabbar{flex-shrink:0;display:grid;grid-template-columns:repeat(5,1fr);align-items:center;height:56px;margin:0 8px;padding:4px 4px 0;background:var(--surface);border:1px solid var(--edge);border-radius:20px}
.tabbar span{display:flex;flex-direction:column;align-items:center;gap:3px;color:var(--subtext);font-size:10px}
.tabbar .on{color:var(--action);font-weight:600}
.tabbar .add svg{background:var(--action);color:var(--onaction);border-radius:10px;padding:5px;width:30px;height:30px}
.tabbar .add{color:var(--action);font-weight:600}
.homebar{height:14px;flex-shrink:0;background:var(--base);display:grid;place-items:center}
.homebar:after{content:'';width:96px;height:4px;border-radius:3px;background:var(--text)}
.nohome .homebar{background:var(--base)}
.hd{margin-bottom:14px}
.hd .dl{font-size:10px;color:var(--subtext);margin-bottom:2px}
.hd .tr{display:flex;align-items:center;justify-content:space-between;gap:10px}
.hd h4{font-size:26px;line-height:1.12;letter-spacing:-.7px;font-weight:600}
.hd .acts{display:flex;align-items:center;gap:12px;color:var(--action);font-size:12px;font-weight:600;white-space:nowrap}
.back{display:flex;align-items:center;gap:2px;color:var(--action);font-size:12px;font-weight:600;margin-bottom:4px}
.back svg.i{width:14px;height:14px}
.sub{font-size:10px;color:var(--subtext)}
.tray{background:var(--surface);border:1px solid var(--edge);border-radius:14px;padding:12px;margin-bottom:10px}
.tray>h5,.tray .th{font-size:14px;font-weight:600;line-height:1.25;margin:0 0 6px;display:flex;justify-content:space-between;align-items:baseline;gap:8px}
.tray .th small{font-size:10px;color:var(--subtext);font-weight:400}
.today{background:var(--tint);border-color:var(--tint);border-radius:20px 20px 7px 20px;padding:14px}
.lab{font-size:10px;color:var(--subtext)}
.hero{font-size:34px;line-height:1.1;font-weight:500;letter-spacing:-1.2px;white-space:nowrap;margin:4px 0 6px}
.big{font-size:26px;line-height:1.15;font-weight:500;letter-spacing:-.7px;white-space:nowrap}
.mid{font-size:18px;line-height:1.2;font-weight:500;letter-spacing:-.3px;white-space:nowrap}
.guide{font-size:12px;font-weight:600;margin-top:6px}
.link{font-size:12px;color:var(--action);font-weight:600;margin-top:8px;display:flex;align-items:center;gap:4px}
.row{display:flex;align-items:center;gap:9px;padding:7px 0;border-bottom:1px solid var(--edge)}
.row:last-child{border-bottom:0}
.rc{flex:1;min-width:0}
.rc b{display:block;font-size:12px;font-weight:600;line-height:1.25}
.rc small{display:block;font-size:10px;color:var(--subtext);margin-top:2px;line-height:1.3}
.amt,.hero,.big,.mid,.amtf strong,.canvas-amount strong{font-family:'Instrument Sans',Arial,sans-serif;font-variant-numeric:tabular-nums}
.amt{font-size:12px;font-weight:600;white-space:nowrap;text-align:right}
.row>.amt{flex-shrink:0}
.amt small{display:block;font-size:10px;font-weight:400;color:var(--subtext)}
.inc{color:var(--income)}
.exp{color:var(--expense)}
.mov{color:var(--text)}
.med{width:30px;height:30px;border-radius:9px;background:var(--tint);display:grid;place-items:center;color:var(--c,var(--action));flex-shrink:0}
.med svg.i{width:17px;height:17px}
.med.sq{border-radius:8px}
.dayh{display:flex;justify-content:space-between;align-items:baseline;font-size:10px;color:var(--subtext);padding:10px 0 2px;gap:8px}
.dayh b{font-size:12px;color:var(--text);font-weight:600}
.dayh .amt{font-size:12px}
.date{width:30px;text-align:center;flex-shrink:0;line-height:1.05}
.date b{display:block;font-size:18px;font-weight:600}
.date small{font-size:10px;color:var(--subtext)}
.band{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:4px 6px;align-items:end;padding:10px 12px;background:var(--surface);border:1px solid var(--edge);border-radius:14px;margin-bottom:10px}
.band>div{min-width:0}
.band .lead{grid-column:1 / -1}
.band small{display:block;font-size:10px;color:var(--subtext)}
.band b{display:block;font-size:12px;font-weight:600;white-space:nowrap;margin-top:2px}
.band .lead b{font-size:18px;font-weight:500;letter-spacing:-.3px}
.band.three{grid-template-columns:repeat(2,minmax(0,1fr))}
.seg{display:flex;gap:2px;background:var(--tint);border:1px solid var(--control);border-radius:10px;padding:2px;margin:0 0 10px}
.seg span{flex:1;text-align:center;padding:6px 2px;font-size:12px;color:var(--subtext);border-radius:8px;white-space:nowrap}
.seg .on{background:var(--raised);color:var(--text);font-weight:600;box-shadow:inset 0 -2px 0 var(--action)}
.seg.sm span{font-size:10px;padding:5px 2px}
.period{display:grid;grid-template-columns:28px minmax(0,1fr) 28px;align-items:center;text-align:center;margin:2px 0 4px}
.period .ar{width:28px;height:28px;border-radius:8px;background:var(--surface);color:var(--action);display:grid;place-items:center}
.period .ar.off{background:transparent;border:1px dashed var(--edge);color:var(--subtext);opacity:.6}
.period b{font-size:12px;font-weight:600}
.period b small{display:block;font-weight:400;font-size:10px;color:var(--subtext)}
.bars{height:92px;display:grid;grid-template-columns:repeat(var(--n,12),minmax(0,1fr));gap:5px;align-items:end;border-bottom:1px solid var(--control);margin-top:10px}
.bars .b{height:100%;display:flex;align-items:flex-end;justify-content:center}
.bars .b i{display:block;width:74%;background:var(--action);border-radius:3px 3px 0 0}
.bars .b.p i{background:var(--incomplete);border:1px solid var(--action);border-bottom:0}
.bars .b.g i{height:9px!important;background:transparent;border:1.5px dashed var(--gap);border-bottom:0}
.bars .b.x i{display:none}
.bars .b.sel i{background:var(--selectedmark);border:0;outline:0;box-shadow:none}
.bars.yr{grid-template-columns:repeat(3,minmax(0,1fr));gap:32px;padding:0 18px}
.bars.yr .b i{width:62%}
.bars.mini{height:58px;gap:4px;margin-top:6px}
.bars .lim{position:absolute;left:0;right:0;border-top:1.5px dashed var(--text)}
.axis{display:grid;grid-template-columns:repeat(var(--n,12),minmax(0,1fr));gap:5px;margin-top:4px;font-size:10px;color:var(--subtext);text-align:center}
.axis .sel{color:var(--text);font-weight:700}
.axis.yr{grid-template-columns:repeat(3,minmax(0,1fr));gap:32px;padding:0 18px;font-size:12px}
.axis.mini{gap:4px}
.qual{font-size:10px;color:var(--subtext);margin-top:6px;line-height:1.4}
.selp{display:flex;justify-content:space-between;align-items:baseline;gap:8px;margin-top:12px}
.selp .lab{font-size:12px;color:var(--text);font-weight:600}
.selp .lab small{display:block;font-weight:400;font-size:10px;color:var(--subtext)}
.selp .big{font-size:24px}
.usual{border-top:1px solid var(--edge);border-bottom:1px solid var(--edge);padding:6px 0;margin-top:6px}
.usual b{display:block;font-size:12px;font-weight:600}
.usual small{display:block;font-size:10px;color:var(--subtext);margin-top:2px}
.bkh{display:flex;justify-content:space-between;align-items:baseline;margin:12px 0 4px}
.bkh h5{font-size:14px;font-weight:600;margin:0}
.bkh small{font-size:10px;color:var(--subtext)}
.donut{width:132px;height:132px;margin:4px auto 6px;position:relative}
.donut svg{width:100%;height:100%;display:block;transform:rotate(-90deg)}
.donut .ctr{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:12px;line-height:1.3;text-align:center}
.donut .ctr b{font-size:14px;font-weight:600}
.donut .ctr small{font-size:10px;color:var(--subtext)}
.cmap{position:relative;height:136px;margin:6px 0 4px}
.cmap .blk{position:absolute;border-radius:8px;padding:8px;color:var(--oncategory);font-weight:600;display:flex;flex-direction:column;justify-content:flex-start;gap:2px;overflow:hidden}
.cmap .blk span{font-size:12px;line-height:1.2}
.cmap .blk small{font-size:10px;font-weight:600;opacity:.95}
.adjl{display:flex;flex-wrap:wrap;gap:4px 12px;font-size:10px;color:var(--subtext);margin:4px 0 6px}
.adjl span{display:flex;align-items:center;gap:5px}
.adjl i,.km{width:10px;height:10px;border-radius:3px;display:inline-block;flex-shrink:0;background:var(--c)}
.rank .rr{display:grid;grid-template-columns:12px minmax(0,1fr) auto 12px;gap:8px;align-items:center;padding:7px 0;border-bottom:1px solid var(--edge)}
.rank .rr:last-child{border-bottom:0}
.rank .rr b{font-size:12px;font-weight:600;display:block}
.rank .rr small{font-size:10px;color:var(--subtext);display:block;margin-top:2px}
.rank .rr .amt{color:var(--expense)}
.rank .rr svg.i{width:12px;height:12px;color:var(--subtext)}
.ctrack{height:7px;border-radius:4px;background:var(--tint);overflow:hidden;margin-top:5px}
.ctrack i{display:block;height:100%;background:var(--c,var(--action));border-radius:4px}
.ctrack.over i{background:var(--expense)}
.catrow{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:2px 8px;padding:7px 0;border-bottom:1px solid var(--edge)}
.catrow:last-child{border-bottom:0}
.catrow b{font-size:12px;font-weight:600}
.catrow .ctrack{grid-column:1 / -1}
.chips{display:flex;gap:6px;flex-wrap:wrap;margin:6px 0 10px}
.chips span{border:1px solid var(--control);border-radius:8px;padding:4px 9px;font-size:10px;color:var(--text);white-space:nowrap;background:var(--surface)}
.chips .on{background:var(--raised);font-weight:600;box-shadow:inset 0 -2px 0 var(--action)}
.search{display:flex;align-items:center;gap:8px;background:var(--surface);border:1px solid var(--control);border-radius:10px;padding:7px 10px;font-size:12px;color:var(--subtext);margin-bottom:10px}
.search.focus{border-color:var(--control);border-bottom:2px solid var(--focus);color:var(--text)}
.wk{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:5px;margin:4px 0 2px}
.wk>div{text-align:center;font-size:10px}
.wk .wb{height:40px;background:transparent;border-radius:6px;display:flex;align-items:flex-end;justify-content:center}
.wk .wb i{display:block;width:48%;background:var(--action);border-radius:2px 2px 0 0}
.wk .wb i.g{background:transparent;border:1.5px dashed var(--gap);border-bottom:0;height:8px!important}
.wk b{display:block;font-size:10px;font-weight:600;margin-top:3px;white-space:nowrap}
.wk small{display:block;color:var(--subtext);white-space:nowrap}
.form-card{background:var(--surface);border-radius:14px;padding:0 10px;box-shadow:inset 0 0 0 1px var(--edge)}
.fld{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid var(--edge);font-size:12px}
.fld>span:first-child{color:var(--subtext);flex-shrink:0}
.fld b{font-weight:500;text-align:right;display:flex;align-items:center;gap:4px;justify-content:flex-end}
.fld b svg.i{width:13px;height:13px;color:var(--subtext)}
.fld.focus{border-bottom:2px solid var(--focus)}
.fld.invalid{box-shadow:inset 0 -2px var(--error)}
.caret{display:inline-block;width:1.5px;height:1.05em;background:var(--focus);vertical-align:-2px;margin-left:1px}
.fld.stack{flex-direction:column;align-items:stretch;gap:3px}
.fld.stack b{text-align:left;justify-content:flex-start}
.fld.locked b{color:var(--subtext)}
.fhint{font-size:10px;color:var(--subtext);margin:5px 0 4px;line-height:1.4}
.ferr{font-size:10px;color:var(--error);margin:5px 0 4px}
.amtf{padding:6px 10px 8px;background:var(--surface);border-radius:12px 12px 0 0;border-bottom:2px solid var(--focus);margin-bottom:8px}
.amtf.idle{border-bottom:1px solid var(--edge)}
.amtf small{display:block;font-size:10px;color:var(--subtext)}
.amtf strong{display:block;font-size:34px;line-height:1.2;font-weight:500;letter-spacing:-1px;white-space:nowrap}
.sw{width:32px;height:19px;border-radius:10px;background:var(--tint);border:1px solid var(--control);position:relative;flex-shrink:0}
.sw:after{content:'';position:absolute;top:2px;left:2px;width:13px;height:13px;border-radius:50%;background:var(--control)}
.sw.on{background:var(--action);border-color:var(--action)}
.sw.on:after{left:15px;background:var(--onaction)}
.btn{display:block;text-align:center;border-radius:10px;padding:10px 12px;font-size:12px;font-weight:600;background:var(--action);color:var(--onaction);border:1px solid var(--action);margin-top:10px}
.btn.sec{background:transparent;color:var(--action);border-color:var(--control)}
.btn.quiet{background:transparent;color:var(--action);border-color:transparent;padding:6px 0}
.btn.danger{background:transparent;color:var(--error);border-color:transparent;padding:8px 0}
.btn.dis{opacity:.45}
.btn.dangerfill{background:var(--error);border-color:var(--error);color:var(--surface)}
.pad{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:4px;margin:6px 0 0}
.key{background:var(--surface);border:1px solid var(--control);border-radius:8px;text-align:center;font-size:16px;font-weight:500;padding:2px 0;line-height:1.3}
.kbd{background:var(--raised);margin:8px -14px -14px;padding:7px 4px 10px;display:grid;gap:7px;border-top:1px solid var(--edge)}
.kbd div{display:flex;justify-content:center;gap:4px}
.kbd span{background:var(--surface);border-radius:5px;min-width:24px;padding:7px 0;text-align:center;font-size:13px;box-shadow:0 1px 0 var(--edge)}
.kbd .w{min-width:36px;font-size:11px}
.kbd .sp{flex:1;max-width:150px;font-size:11px}
.under{padding:12px 14px 0;min-height:0;overflow:hidden;flex:1}
.sheetwrap{position:relative;flex:1;min-height:0;display:flex;flex-direction:column;overflow:hidden;padding:0!important}
.sheet{background:var(--raised);border-top:2px solid var(--control);border-radius:22px 22px 0 0;padding:8px 14px 14px;flex:0 1 auto;max-height:500px;display:flex;flex-direction:column;min-height:0;overflow:hidden;box-shadow:0 -8px 22px rgba(25,61,83,.14)}
.phone.compact .sheet{max-height:366px}
.sheet .handle,.sheet>.shh,.sheet-footer{flex-shrink:0}
.sheet-scroll{flex:0 1 auto;min-height:0;overflow:auto;overscroll-behavior:contain;scrollbar-width:thin}
.sheet-backdrop{position:absolute;inset:0;display:flex;flex-direction:column}
.sheet-front{position:relative;z-index:1}
.sheet-alert{position:absolute;top:46px;left:12px;right:12px;z-index:6;border:1px solid var(--error);border-radius:10px;padding:10px 12px;background:var(--errorbg);color:var(--error);font-size:12px;line-height:1.45;box-shadow:0 4px 14px rgba(0,0,0,.12)}
.sheet-alert b,.sheet-alert small{display:block}
.sheet-alert small{font-size:10px;margin-top:2px}
.sheet-alert.warning{background:var(--noticebg);color:var(--notice);border-color:var(--notice)}
.sheet-alert.neutral{background:var(--text);color:var(--base);border-color:var(--text)}
.sheet-footer{display:flex;flex-direction:column}
.sheet-footer .btn{margin-top:8px}
.sheet-footer .pad,.sheet-footer .kbd{order:2}
html[data-app=dark] .app:not(.force-light) .sheet,.app.force-dark .sheet{box-shadow:none}
.handle{width:34px;height:4px;border-radius:3px;background:var(--control);margin:0 auto 8px}
.shh{display:grid;grid-template-columns:52px minmax(0,1fr) 52px;gap:4px;align-items:center;margin-bottom:6px}
.shh span{font-size:12px;color:var(--action);font-weight:600}
.shh span:last-child{text-align:right}
.shh h4{font-size:18px;font-weight:600;text-align:center;line-height:1.2}
.sheet.keypad{min-height:0}
.sheet.keypad .fld{padding:8px 0}
.sheet.keypad .seg{margin-bottom:8px}
.sheet.keypad .seg span{padding:5px 2px}
.sheet.keypad .amtf strong{font-size:32px}
.sheet.keypad .notice,.sheet.keypad .err{padding:7px 9px;font-size:11px;line-height:1.3}
.sheet.keypad .notice b,.sheet.keypad .err b{font-size:11px}
.sheet.keypad .btn{padding:8px 12px;margin-top:8px}
.sheet.keypad .btn.danger{padding:6px 0}
.shh span.primary-action{background:var(--action);color:var(--onaction);border-radius:8px;padding:6px 4px;text-align:center}
.dialog .da>span:last-child{background:var(--action);color:var(--onaction);border-radius:8px;padding:7px 12px}
.dialog .da>span:last-child.d{background:var(--error);color:var(--onaction)}
.dialog .da{align-items:center}
.notice .na{align-items:center;text-decoration:none;flex-wrap:wrap}
.notice .na>span:first-child{background:var(--action);color:var(--onaction);border-radius:8px;padding:7px 10px}
.sync-symbol{background:transparent!important}
.sync-progress{padding:10px;border-radius:16px;background:var(--surface);border:1px solid var(--edge)}
.sync-progress .spin{display:block;border-color:var(--control);border-top-color:var(--action)}
.canvas-amount{color:var(--expense);margin:0 0 10px}
.canvas-amount strong{font-size:26px;line-height:1.15;font-weight:500;letter-spacing:-.7px;white-space:nowrap}

.sheetwrap .tray{background:var(--surface)}
.scrim{position:absolute;inset:0;background:rgba(16,17,18,.32);display:flex;align-items:center;justify-content:center;padding:22px;z-index:5}
.dialog{background:var(--raised);border:1px solid var(--control);border-radius:16px;padding:16px;width:100%}
.dialog h4{font-size:18px;font-weight:600;margin-bottom:6px}
.dialog p{font-size:12px;color:var(--subtext);line-height:1.45}
.dialog .da{display:flex;justify-content:flex-end;gap:18px;margin-top:14px;font-size:12px;font-weight:600;color:var(--action)}
.dialog .da .d{color:var(--error)}
.snack{position:absolute;left:12px;right:12px;bottom:12px;background:var(--text);color:var(--base);border-radius:10px;padding:10px 12px;font-size:12px;display:flex;justify-content:space-between;gap:10px;align-items:center;z-index:4}
.snack b{color:var(--base);text-decoration:underline;white-space:nowrap}
.notice{background:var(--noticebg);color:var(--notice);border:1px solid var(--notice);border-left-width:3px;border-radius:10px;padding:10px 12px;margin-bottom:10px;font-size:12px;line-height:1.45}
.notice b{display:block;font-size:12px;margin-bottom:2px}
.notice .na{display:flex;gap:14px;margin-top:6px;font-weight:600}
.err{background:var(--errorbg);color:var(--error);border:1px solid var(--error);border-radius:10px;padding:10px 12px;font-size:12px;line-height:1.45;margin:8px 0}
.err b{display:block}
.err small{display:block;font-size:10px;margin-top:2px;opacity:.9}
.statusline{display:flex;align-items:center;gap:8px;font-size:10px;color:var(--subtext);background:var(--surface);border:1px solid var(--edge);border-radius:10px;padding:7px 10px;margin-bottom:10px}
.fab{position:absolute;right:14px;bottom:14px;background:var(--action);color:var(--onaction);border-radius:14px;padding:10px 14px 10px 11px;font-size:12px;font-weight:600;display:flex;align-items:center;gap:6px;z-index:3}
.fab svg.i{width:16px;height:16px}
.reserve{height:58px}
.skel{background:var(--tint);border-radius:7px;height:12px;margin:7px 0}
.skel.w6{width:60%}.skel.w4{width:40%}.skel.w8{width:80%}.skel.t{height:30px;width:55%}
.spin{width:18px;height:18px;border-radius:50%;border:2px solid var(--surface);border-top-color:var(--action);flex-shrink:0}
.spin.l{width:30px;height:30px;border-width:3px}
.center{display:flex;flex-direction:column;align-items:center;text-align:center;justify-content:center;gap:8px}
.empty{text-align:center;padding:22px 12px}
.empty .med{margin:0 auto 10px;width:44px;height:44px;border-radius:13px}
.empty .med svg.i{width:22px;height:22px}
.empty b{display:block;font-size:14px;font-weight:600}
.empty p{font-size:12px;color:var(--subtext);margin:5px auto 0;max-width:230px}
.empty .btn{display:inline-block;padding:9px 16px}
.cal{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:3px;text-align:center;font-size:10px}
.cal .h{color:var(--subtext);padding:3px 0}
.cal span{padding:5px 0;border-radius:7px;line-height:1.1}
.cal .rec{background:var(--tint);font-weight:600}
.cal .plan{border:1.5px dashed var(--control)}
.cal .sel{background:var(--action);color:var(--onaction);font-weight:700}
.cal .today{outline:1.5px solid var(--text)}
.mgrid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;margin:10px 0}
.mgrid span{text-align:center;padding:9px 0;border-radius:9px;border:1px solid var(--edge);font-size:12px;background:var(--surface)}
.mgrid .on{background:var(--action);color:var(--onaction);border-color:var(--action);font-weight:600}
.pick{display:flex;justify-content:space-between;align-items:center;padding:10px 0;border-bottom:1px solid var(--edge);font-size:12px;gap:8px}
.pick.ind{padding-left:22px}
.pick .ck{color:var(--action)}
.pick small{display:block;font-size:10px;color:var(--subtext);margin-top:2px}
.pick.dis{color:var(--subtext)}
.twocol{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.twocol>div{border-right:1px solid var(--edge);padding-right:8px}
.twocol>div:last-child{border-right:0}
.editrow{display:flex;align-items:center;gap:8px;background:var(--surface);border:1px solid var(--control);border-radius:12px;padding:10px;margin:8px 0}
.editrow .rc b{font-size:12px}
.editrow .grip{color:var(--subtext)}
.editrow .mv{display:flex;gap:6px;color:var(--action)}
.editrow .mv svg.i{width:16px;height:16px}
.editrow .mv .off{color:var(--subtext);opacity:.45}
.editrow .hide{font-size:12px;color:var(--action);font-weight:600}
.chooser{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:9px 0;border-bottom:1px solid var(--edge)}
.chooser b{display:block;font-size:12px;font-weight:600}
.chooser small{display:block;font-size:10px;color:var(--subtext);margin-top:2px}
.chooser .ad{color:var(--action);font-weight:600;white-space:nowrap;font-size:12px}
.chooser .ad.done{color:var(--subtext);font-weight:400}
.setrow{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid var(--edge);font-size:12px}
.setrow:last-child{border-bottom:0}
.setrow b{font-weight:600;display:block}
.setrow small{display:block;font-size:10px;color:var(--subtext);margin-top:2px;font-weight:400}
.setrow .val{color:var(--subtext);display:flex;align-items:center;gap:4px;white-space:nowrap}
.setrow .val svg.i{width:13px;height:13px}
.opt3{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;margin-top:8px}
.opt3 span{border:1px solid var(--control);border-radius:10px;padding:8px 2px;text-align:center;font-size:12px;background:var(--surface)}
.opt3 .on{border:2px solid var(--action);background:var(--raised);font-weight:600;padding:7px 1px}
.opt3 .on:before{content:'\\2713';display:block;color:var(--action);font-size:12px;line-height:1}
.opt3 span:not(.on):before{content:'';display:block;height:12px}
.setlab{font-size:10px;color:var(--subtext);margin:12px 0 4px;font-weight:600}
.prevs{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}
.prevs>div{border:1px solid var(--control);border-radius:10px;padding:8px;background:var(--surface);text-align:center;font-size:12px}
.prevs>div.on{border:2px solid var(--action);padding:7px}
.prevs .mini-d{width:58px;height:58px;margin:4px auto}
.prevs .cmap{height:58px;margin:4px 0}
.prevs .cmap .blk{padding:3px;border-radius:4px}
.receipt-img{background:#F7F7F2;color:#2A2A2A;border-radius:4px;padding:14px 12px;font-size:10px;line-height:1.5;font-family:'Instrument Sans',Arial,sans-serif;box-shadow:0 1px 0 rgba(0,0,0,.2)}
.receipt-img b{display:block;font-size:12px}
.croparea{position:relative;margin:14px 10px;padding:12px;transform:rotate(-2deg)}
.croparea .hdl{position:absolute;width:16px;height:16px;border-radius:50%;background:var(--surface);border:3px solid var(--action)}
.croparea:after{content:'';position:absolute;inset:4px;border:2px solid var(--action);border-radius:2px;pointer-events:none}
.kv{display:flex;justify-content:space-between;gap:10px;padding:10px 0;border-bottom:1px solid var(--edge);font-size:12px}
.kv:last-child{border-bottom:0}
.kv span{color:var(--subtext)}
.kv b{font-weight:600;white-space:nowrap}
.pocket{display:flex;justify-content:space-between;font-size:10px;padding:3px 0 3px 39px;color:var(--subtext)}
.pocket b{font-weight:500;color:var(--text)}
.grouph{font-size:10px;color:var(--subtext);font-weight:600;margin:10px 0 2px}
.code6{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:6px;margin:10px 0}
.code6 span{border-bottom:2px solid var(--control);text-align:center;font-size:22px;font-weight:500;padding:4px 0}
.code6.focus span:last-child{border-bottom-color:var(--focus)}
.code6.bad span{border-bottom-color:var(--error)}
.ins{border-bottom:1px solid var(--edge);padding:8px 0}
.ins:last-child{border-bottom:0}
.ins .t{display:flex;justify-content:space-between;gap:8px}
.ins b{font-size:12px;font-weight:600}
.ins small{display:block;font-size:10px;color:var(--subtext);margin-top:2px}
.ins .x{color:var(--subtext)}
.split{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.split b{display:block;font-size:18px;font-weight:500;margin-top:2px;white-space:nowrap}
.ptwo{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.ptwo>div{min-width:0}
.lockmsg{display:flex;gap:6px;align-items:flex-start;font-size:10px;color:var(--subtext);margin:8px 0}
.menu{position:absolute;right:14px;top:84px;background:var(--raised);border:1px solid var(--control);border-radius:12px;padding:4px 0;width:200px;z-index:6;box-shadow:0 8px 20px rgba(25,61,83,.16)}
.menu span{display:flex;gap:9px;align-items:center;padding:9px 12px;font-size:12px}
.menu span.d{color:var(--error)}
.menu span+span{border-top:1px solid var(--edge)}
.swipe{display:flex;align-items:stretch;border-radius:10px;overflow:hidden;margin:4px 0}
.swipe .act{display:flex;align-items:center;gap:6px;padding:0 12px;font-size:12px;font-weight:600}
.swipe .act.r{background:var(--action);color:var(--onaction)}
.swipe .act.d{background:var(--error);color:var(--surface)}
.swipe .row{flex:1;background:var(--surface);padding:8px 10px;border:1px solid var(--edge)}
.boot{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;padding:30px}
.wordmark{font-size:26px;font-weight:600;letter-spacing:-.8px}
.wordmark i{font-style:normal;color:var(--action)}
.tag{font-size:10px;border-radius:6px;padding:2px 6px;background:transparent;color:var(--subtext);white-space:nowrap}
.tag.warn{background:var(--noticebg);color:var(--notice)}
.tag.bad{background:var(--errorbg);color:var(--error)}
.tag.ok{background:transparent;color:var(--income)}
/* desktop */
.win{width:100%;border:1px solid var(--control);border-radius:12px;overflow:hidden;font-size:12px;background:var(--base)}
.wbar{height:32px;display:flex;align-items:center;justify-content:space-between;padding:0 12px;background:var(--surface);border-bottom:1px solid var(--edge);font-size:11px;color:var(--subtext)}
.wbar .dots{display:flex;gap:6px}
.wbar .dots i{width:11px;height:11px;border-radius:3px;border:1px solid var(--control);display:block}
.wbody{display:grid;grid-template-columns:172px minmax(0,1fr);min-height:600px}
.side{background:var(--surface);border-right:1px solid var(--edge);padding:18px 10px;display:flex;flex-direction:column;gap:3px}
.side .wordmark{font-size:18px;margin:0 8px 16px}
.side span{display:flex;align-items:center;gap:10px;padding:8px 9px;border-radius:9px;color:var(--subtext);font-size:12px}
.side span.on{background:var(--tint);color:var(--action);font-weight:600}
.side .gap{flex:1}
.side .syn{font-size:10px;padding:8px 9px;color:var(--subtext);display:block}
.ws{padding:18px 22px 22px;min-width:0;position:relative}
.whead{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;margin-bottom:16px;flex-wrap:wrap}
.whead h4{font-size:26px;font-weight:600;letter-spacing:-.7px;line-height:1.15}
.whead .acts{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.whead .acts span{display:flex;align-items:center;gap:6px;font-size:12px;color:var(--action);font-weight:600;white-space:nowrap}
.whead .acts .pbtn{background:var(--action);color:var(--onaction);border-radius:9px;padding:7px 12px}
.whead .acts .sbtn{border:1px solid var(--control);border-radius:9px;padding:6px 10px;color:var(--text);font-weight:400}
.dg3{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;align-items:start}
.dg2{display:grid;grid-template-columns:minmax(0,1.35fr) minmax(0,1fr);gap:18px;align-items:start}
.dg2e{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:18px;align-items:start}
.dcol{display:grid;gap:14px;align-content:start}
.dcol .tray{margin:0}
.win .bars{height:150px}
.win .bars.mini{height:62px}
.win .donut{width:150px;height:150px}
.win .cmap{height:160px}
.pane{background:var(--surface);border:1px solid var(--edge);border-radius:14px;padding:14px}
.pane.raised{background:var(--raised);border-color:var(--control)}
table.reg{width:100%;border-collapse:collapse;font-size:12px}
table.reg th{text-align:left;font-size:10px;color:var(--subtext);font-weight:600;padding:6px 8px;border-bottom:1px solid var(--control)}
table.reg td{padding:8px;border-bottom:1px solid var(--edge);vertical-align:middle}
table.reg td.r,table.reg th.r{text-align:right;white-space:nowrap}
table.reg tr.sel td{background:var(--raised)}
table.reg tr.sel td:first-child{box-shadow:inset 3px 0 0 var(--action)}
table.reg .dayrow td{font-size:10px;color:var(--subtext);background:var(--base);padding:5px 8px}
.wscrim{position:absolute;inset:0;background:rgba(16,17,18,.18)}
.dpanel{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:340px;max-height:calc(100% - 32px);border-radius:18px;overflow:hidden;background:var(--raised);border:2px solid var(--control);padding:16px 18px;display:flex;flex-direction:column;box-shadow:-10px 0 24px rgba(25,61,83,.12)}
html[data-app=dark] .app:not(.force-light) .dpanel,.app.force-dark .dpanel{box-shadow:none}
html[data-app=dark] .app:not(.force-light) .vd:not(:last-child)>.row:last-child,.app.force-dark .vd:not(:last-child)>.row:last-child{border-bottom:1px solid var(--edge)}
html:not([data-app=dark]) .app:not(.force-dark) .light-only,.app.force-light .light-only{display:contents}
html:not([data-app=dark]) .app:not(.force-dark) .light-card,.app.force-light .light-card{background:var(--surface);border-radius:14px;padding:12px;margin-bottom:10px;box-shadow:inset 0 0 0 1px var(--edge)}
html:not([data-app=dark]) .app:not(.force-dark) .day-card,.app.force-light .day-card{padding:0 12px}
html:not([data-app=dark]) .app:not(.force-dark) .chart-card .seg,.app.force-light .chart-card .seg{margin-bottom:8px}
html:not([data-app=dark]) .app:not(.force-dark) .breakdown-card .bkh,.app.force-light .breakdown-card .bkh{margin-top:0}
html:not([data-app=dark]) .app:not(.force-dark) .form-card,.app.force-light .form-card{padding:0 10px;margin-bottom:0}
html:not([data-app=dark]) .app:not(.force-dark) .sheet .form-card,.app.force-light .sheet .form-card{flex-shrink:0}
html:not([data-app=dark]) .app:not(.force-dark) .sheet:has(.form-card),.app.force-light .sheet:has(.form-card){background:var(--base)}
html:not([data-app=dark]) .app:not(.force-dark) .dpanel,.app.force-light .dpanel{background:var(--base)}
html:not([data-app=dark]) .app:not(.force-dark) .pad,.app.force-light .pad{background:var(--surface);border-radius:10px;box-shadow:0 0 0 1px var(--edge)}
html:not([data-app=dark]) .app:not(.force-dark) .empty,.app.force-light .empty{background:var(--surface);border-radius:14px;box-shadow:inset 0 0 0 1px var(--edge)}
html:not([data-app=dark]) .app:not(.force-dark) .today,.app.force-light .today{background:var(--surface);border-color:var(--edge)}
html:not([data-app=dark]) .app:not(.force-dark) .seg,.app.force-light .seg{background:var(--surface);border-color:var(--edge)}
html:not([data-app=dark]) .app:not(.force-dark) .seg .on,.app.force-light .seg .on{color:var(--action)}
html:not([data-app=dark]) .app:not(.force-dark) .chips .on,.app.force-light .chips .on{color:var(--action)}
html:not([data-app=dark]) .app:not(.force-dark) .axis .sel,.app.force-light .axis .sel{color:var(--action)}
html:not([data-app=dark]) .app:not(.force-dark) .wk .wb:empty,.app.force-light .wk .wb:empty{background:transparent}
html:not([data-app=dark]) .app:not(.force-dark) .sheet,.app.force-light .sheet{border-top:1px solid var(--edge);box-shadow:0 -8px 22px rgba(0,0,0,.10)}
html:not([data-app=dark]) .app:not(.force-dark) .menu,.app.force-light .menu{border-color:var(--edge);box-shadow:0 8px 20px rgba(0,0,0,.12)}
html:not([data-app=dark]) .app:not(.force-dark) .dpanel,.app.force-light .dpanel{border:1px solid var(--edge);box-shadow:-10px 0 24px rgba(0,0,0,.10)}
html:not([data-app=dark]) .app:not(.force-dark) .pane.raised,.app.force-light .pane.raised{border-color:var(--edge)}
@media(max-width:1250px){.wbody{grid-template-columns:150px minmax(0,1fr)}.dg3{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:1000px){.wbody{grid-template-columns:132px minmax(0,1fr)}.ws{padding:16px}.dg2,.dg2e{grid-template-columns:1fr}.dpanel{width:300px}}
@media(max-width:760px){.wbody{grid-template-columns:1fr}.side{flex-direction:row;flex-wrap:wrap;border-right:0;border-bottom:1px solid var(--edge)}.side .gap{display:none}.dg3{grid-template-columns:1fr}.dpanel{width:calc(100% - 32px)}}
"""
)
