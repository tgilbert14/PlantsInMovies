from pathlib import Path
import math
out=Path(__file__).resolve().parents[1] / 'www' / 'cinema'
base='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 440" fill="none"><g stroke="{c}" stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>'
# Original botanical illustrations: visual motifs only, not species identifications.
cactus='<ellipse cx="310" cy="394" rx="174" ry="14" stroke-width="1" opacity=".25"/><path d="M259 391V89C259 30 331 30 331 89V391 M259 249H213C184 249 166 225 166 201V151C166 121 201 121 201 151V202C201 210 207 216 215 216H259 M331 302H372C404 302 422 278 422 248V199C422 172 386 172 386 199V250C386 261 380 266 369 266H331" stroke-width="3"/>'
for x in [270,282,295,308,320]:
 cactus+=f'<path d="M{x} 385V93Q{x} 63 295 63" stroke-width="1" opacity=".6"/>'
for y in range(95,382,30):
 for x in [260,281,308,330]:
  cactus+=f'<path d="M{x-4} {y-4}l8 8m-8 0 8-8" stroke-width=".7"/>'
cactus+='<path d="M104 392Q109 341 133 314Q153 351 152 392 M116 391Q108 365 88 353 M143 392Q154 362 175 351" stroke-width="2"/><circle cx="433" cy="79" r="45" stroke-width="1" opacity=".45"/><path d="M70 408H518" opacity=".35"/>'
# Branch with leaves and a stylized rosette.
branch='<path d="M260 410Q261 223 360 49 M291 286Q188 241 148 174 M319 198Q408 159 445 95 M276 345Q373 319 410 261" stroke-width="3"/>'
for x,y,ang,scale in [(292,285,-55,1),(257,264,-80,.8),(215,239,-60,.9),(317,199,45,1),(355,178,60,.8),(389,155,45,.8),(336,109,-40,.8),(351,75,35,.7),(277,345,45,.9),(320,329,60,.7),(369,300,50,.9)]:
 branch+=f'<g transform="translate({x} {y}) rotate({ang}) scale({scale})"><path d="M0 0Q-52-27 0-86Q52-27 0 0Z M0 0V-80" stroke-width="1.8"/><path d="M0-18-21-35M0-33-17-51M0-47-10-66M0-23 20-41M0-40 13-58" stroke-width=".8"/></g>'
for a in range(0,360,60): branch+=f'<ellipse cx="151" cy="149" rx="13" ry="30" transform="rotate({a} 151 172)" stroke-width="1.5"/>'
branch+='<circle cx="151" cy="172" r="10" stroke-width="2"/><path d="M80 415H514" opacity=".3"/>'
fern='<path d="M288 415Q258 189 348 29" stroke-width="3"/>'
for i in range(15):
 y=383-i*23; x=284+(i/14)**2*58; length=105*math.sin((i+2)/18*math.pi)
 for side in [-1,1]:
  endx=x+side*length; endy=y-57
  fern+=f'<path d="M{x:.1f} {y}Q{endx:.1f} {y-10} {endx:.1f} {endy}" stroke-width="1.5"/>'
  for j in range(1,9):
   f=j/10; px=x+side*length*f; py=y-57*f*f; size=17*(1-f)+4
   fern+=f'<path d="M{px:.1f} {py:.1f}q{-side*9} {-size:.1f} {side*4} {-size-10:.1f}q{side*12} {size/2:.1f} {-side*4} {size+10:.1f} M{px:.1f} {py:.1f}q{side*17} 8 {side*24} -2" stroke-width=".8"/>'
fern+='<path d="M72 415H520" opacity=".3"/>'
for name,c,body in [('arrakis','#E9AD68',cactus),('middleearth','#BBD277',branch),('islanublar','#99D4CE',fern)]:
 (out/f'{name}-v1.svg').write_text(base.format(c=c,body=body))
print('Created three original SVG botanical plates.')
