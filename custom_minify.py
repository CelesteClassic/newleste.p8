import re
from collections import Counter
import string
import itertools
with open("site_shrink.p8") as f:
    data=f.read()

words=re.findall(r"[a-zA-Z_]\w*",data,re.ASCII)

words=words[words.index("__lua__")+1:len(words)-1-words[::-1].index("levels")]
# print(words)

cnts=Counter(words)
# x and b can cause syntax errors from 0b... or 0x....
letters=[c for c in string.ascii_letters if c.lower()not in 'bx']
varnames=itertools.chain(letters, map(lambda x: "".join(x), itertools.product(letters,repeat=2)))
currname=next(varnames)
while currname in words:
    currname=next(varnames)
# print(cnts)
# print(len(cnts))
lua_keywords="and,break,do,else,elseif,end,false,for,function,if,in,local,nil,not,or,repeat,return,then,true,until,while".split(",")
pico8_builtins="_ENV,ceil,pack,flr,tostring,inext,mapdraw,tonum,logout,extcmd,camera,install_games,keyconfig,del,ord,import,reboot,exit,_update_framerate,export,getmetatable,min,mkdir,clip,sin,cls,_set_mainloop_exists,palt,add,_pausemenu,poke,ipairs,▒,🐱,⬇️,sspr,__type,█,type,fset,install_demos,cursor,max,printh,➡️,★,rectfill,peek4,menuitem,select,peek2,…,웃,atan2,⬅️,😐,✽,rawget,abs,☉,print,scoresub,dir,tostr,serial,sgn,mset,t,sset,assert,pset,map,ovalfill,chr,login,memcpy,tline,save,rnd,yield,shr,s,▥,foreach,░,spr,●,color,costatus,ˇ,⬆️,⧗,reload,info,rawlen,◆,🅾️,rawequal,♪,help,btn,⌂,♥,bor,∧,❎,▤,all,mid,count,pal,deli,set_draw_slice,__flip,split,dset,_mark_cpu,time,line,_set_fps,btnp,fget,cd,_update_buttons,poke2,srand,_startframe,holdframe,trace,__trace,memset,music,rotr,bxor,unpack,coresume,cocreate,rawset,shl,rotl,next,peek,pairs,stop,cartdata,setmetatable,sub,stat,bbsreq,circfill,ls,cstore,_map_display,backup,dget,rect,fillp,sfx,_menuitem,shutdown,radio,band,circ,sqrt,sget,run,flip,poke4,splore,folder,load,pget,_get_menu_item_selected,cos,mget,lshr,oval,bnot,reset".split(",")
for k,c in cnts.most_common():
    if len(k)<=len(currname) or k in lua_keywords or k in pico8_builtins:
        continue

    ans=input(f"replace {k}, {c} with {currname}? [Y/N/Q] ")
    match ans:
        case "q":
            break
        case "n":
            continue
        case "y" | _:
            data=re.sub(k, currname, data)

    currname=next(varnames)
    while currname in words:
        currname=next(varnames)
with open("site_shrink2.p8","w") as f:
    f.write(data)


