import json,glob,os,re,sys,collections,time,difflib
# For every hook refusal (tool_result naming scripts/<x>.sh), find the agent's next tool call and its outcome.
cut=time.time()-int(sys.argv[1] if len(sys.argv)>1 else 30)*86400
pat=re.compile(r'hook error: \[\\?"[^\]]*scripts/([a-z0-9-]+)\.(?:sh|py)')
st=collections.defaultdict(lambda: collections.Counter()); ex=collections.defaultdict(list)
files=glob.glob(os.path.expanduser('~/.claude/projects/**/*.jsonl'),recursive=True)
for f in files:
    if os.path.getmtime(f)<cut: continue
    rows=[]
    for l in open(f,errors='ignore'):
        try: rows.append(json.loads(l))
        except: pass
    calls={}; seq=[]
    for d in rows:
        m=d.get('message') if isinstance(d.get('message'),dict) else {}
        c=m.get('content') if isinstance(m.get('content'),list) else []
        for x in c:
            if x.get('type')=='tool_use': calls[x['id']]=x; seq.append(('use',x))
            elif x.get('type')=='tool_result':
                t=x.get('content'); t=t if isinstance(t,str) else json.dumps(t)
                seq.append(('res',x.get('tool_use_id'),t,x.get('is_error')))
            elif x.get('type')=='text' and d.get('type')=='user': seq.append(('user',))
    for k,e in enumerate(seq):
        if e[0]!='res': continue
        mm=pat.search(e[2][:400])
        if not mm: continue
        h=mm.group(1); src=calls.get(e[1]); st[h]['refusals']+=1
        if not src: continue
        a=json.dumps(src['input'])
        nxt=None; nres=None
        for e2 in seq[k+1:k+12]:
            if e2[0]=='user': break
            if e2[0]=='use' and nxt is None: nxt=e2[1]
            if nxt and e2[0]=='res' and e2[1]==nxt['id']: nres=e2; break
        if not nxt: st[h]['stopped']+=1; continue
        b=json.dumps(nxt['input']); sim=difflib.SequenceMatcher(None,a[:600],b[:600]).ratio()
        ok=nres is not None and not pat.search(nres[2][:400])
        if nxt['name']=='Skill': kind='skill:'+nxt['input'].get('skill','')
        elif sim>0.6 and ok: kind='retry-passed'
        elif sim>0.6: kind='retry-refused'
        elif ok: kind='other-call'
        else: kind='other-refused'
        st[h][kind.split(':')[0]]+=1
        if len(ex[h])<6: ex[h].append((a[:220],kind,b[:220]))
for h,c in sorted(st.items(),key=lambda x:-x[1]['refusals']):
    print(h,dict(c))
json.dump(ex,open(os.path.join(os.path.dirname(__file__),'audit-ex.json'),'w'),indent=1)
