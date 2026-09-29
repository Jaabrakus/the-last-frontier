import json,csv,collections,struct
from lib import *
from decode_lambda import summarize
from resolve import OS,PRIO,subst_map

OUT=__import__('_vendor_paths').SUBGRAPH_OUT  # vendored path shim
rows=list(csv.DictReader(open(__import__('_vendor_paths').INDEX_CSV)))  # vendored path shim
IDX={}
for r in rows:
    k=(r['character'],r['original_name'])
    d=float(r['sample_count'])/float(r['sample_rate'])
    pref={'clip':0,'pose':1,'stitched_stream':2}[r['kind']]
    if k not in IDX or pref<IDX[k]['_p']:
        IDX[k]=dict(duration_s=round(d,4),kind=r['kind'],sample_rate=float(r['sample_rate']),sample_count=int(r['sample_count']),action_name=r['action_name'],blend_file=r['blend_file'],asset_id=r['asset_id'],_p=pref)
def info(char,name):
    v=IDX.get((char,name))
    if not v: return None
    return {k:v[k] for k in v if k!='_p'}

def resolve_fix(clip,sets):
    sets=[s for s in sets if s in OS]
    sets=sorted(sets,key=lambda n: PRIO.get(OS[n]['layer'],99))
    maps=[(n,subst_map(n)) for n in sets]
    chain=[clip]; seen={clip}
    for _ in range(6):
        changed=False
        for n,m in maps:
            c=chain[-1]
            if c in m and m[c] not in seen:
                chain.append(m[c]); seen.add(m[c]); changed=True
        if not changed: break
    return chain

AB='anim-overlay-player-actor_b-actor_b'
MODES={'walk':['anim-overlay-player-move-walk'],
       'run':['anim-overlay-player-move-run'],
       'sprint':['anim-overlay-player-move-run-sprint'],
       'crouch_walk':['anim-overlay-player-move-walk-crouched','anim-overlay-player-crouch-crouch'],
       'crouch_sprint':['anim-overlay-player-move-crouch-sprint','anim-overlay-player-crouch-crouch']}
WEAP={'bow':['anim-overlay-player-weapon-base-bow','anim-overlay-player-weapon-draw-holster-bow'],
      'musket':['anim-overlay-player-weapon-base-long-gun','anim-overlay-player-weapon-sub-type-rifle-no-scope','anim-overlay-player-weapon-draw-holster-long-gun'],
      'pistol':['anim-overlay-player-weapon-base-pistol','anim-overlay-player-weapon-sub-type-pistol-actor_b','anim-overlay-player-weapon-draw-holster-pistol']}

# ---------------- subgraph selection ----------------
SEL=[
 # name, group, layer, optional, note
 ('idle','locomotion','base',False,'standing idle; clip set chosen by move-mode overlay (relax/crouch idle)'),
 ('idle-turn-l','locomotion','base',False,'turn in place left (~90 deg clip for Actor_B)'),
 ('idle-turn-r','locomotion','base',False,'turn in place right'),
 ('idle-turn-l-180','locomotion','base',False,'180 turn in place; no Actor_B remap found -> use quick-turn-180 clip (see optional state)'),
 ('idle-turn-r-180','locomotion','base',False,'180 turn in place; no Actor_B remap found'),
 ('idle^run-fwd','locomotion','base',False,'start (forward family)'),
 ('idle^run-bkwd','locomotion','base',False,'start (backward/strafe-back family, |move_dir|>90)'),
 ('run-fw','locomotion','base',False,'move loop forward family (walk/run/sprint/crouch via move overlay)'),
 ('run-bkwd','locomotion','base',False,'move loop backward family'),
 ('run-fw^idle','locomotion','base',False,'stop from forward move'),
 ('run-bk^idle','locomotion','base',False,'stop from backward move'),
 ('run-fw^run-bkwd-begin','locomotion','base',False,'entry shim for fw->bw reversal (same tree as run-fw^run-bkwd; auto at phase>=0.1, 0 fade)'),
 ('run-fw^run-bkwd','locomotion','base',False,'quick reversal fw->bw (quickstop clip)'),
 ('run-bw^run-fwd-begin','locomotion','base',False,'entry shim for bw->fw reversal'),
 ('run-bw^run-fwd','locomotion','base',False,'quick reversal bw->fw'),
 ('crouch-change-idle^idle','locomotion','base',False,'stand<->crouch transition (clip via crouch-change overlay stand^crouch / crouch^stand)'),
 ('run-jump-long','air','base',False,'jump takeoff (tree shared with idle-jump-long, anim-player:0x00017e8c)'),
 ('jump-long','air','base',False,'airborne jump'),
 ('pre-fall','air','base',False,'walk-off-ledge lead-in'),
 ('fall','air','base',False,'fall loop'),
 ('fall-land-soft-idle','air','base',False,'soft landing to idle'),
 ('fall-land-soft-run','air','base',False,'soft landing to run'),
 ('fall-land-hard-idle','air','base',False,'hard landing to idle'),
 ('fall-land-hard-run','air','base',False,'hard landing to run'),
 ('jump-long-land-idle','air','base',False,'jump landing to idle (only incoming: jump-long via request idle)'),
 ('jump-long-land-run','air','base',False,'jump landing to run'),
 ('aim-idle','aim','base',False,'aim stand; weapon-base overlay picks pistol/long-gun/bow clips; pitch via additive up/down poses'),
 ('aim-run-forward','aim','base',False,'aim strafe forward family'),
 ('aim-run-backward','aim','base',False,'aim strafe backward family'),
 ('fire','weapon','upper_additive',False,'clip id supplied at runtime by callback anim-player:0x0002662c = int32[(info+8)->+236]; rate = float at +236+8'),
 ('idle-pistol-reload-part','weapon','upper_partial',False,'one-shot reload (bow nock / pistol 9mm-style reload); rate callback 0x00017dac'),
 ('idle-shotgun-reload-begin-part','weapon','upper_partial',False,'staged reload begin (musket via rifle-no-scope sub-type)'),
 ('idle-shotgun-reload-mid-part','weapon','upper_partial',False,'staged reload loop'),
 ('idle-shotgun-reload-finish-part','weapon','upper_partial',False,'staged reload end'),
 ('idle-pistol-grab-part','weapon','upper_partial',False,'draw step 1: reach/grab (weapon-draw-holster overlay picks bow/long-gun clips)'),
 ('idle-pistol-draw-part','weapon','upper_partial',False,'draw step 2: grab -> weapon out'),
 ('idle-pistol-holster-part','weapon','upper_partial',False,'holster step 1: SAME clip as draw, start phase 1.0 (cb 0x000155ac) and negative rate (cb 0x0001b24c) = draw played backwards'),
 ('idle-pistol-finish-part','weapon','upper_partial',False,'holster step 2: hand returns to idle'),
 ('hit-reaction-full-body','damage','base',False,'full-body hit; clip id overridden at runtime (clip cb 0x00025a84 = int32[info+280])'),
 ('hit-reaction-par','damage','upper_additive',False,'partial/additive hit reaction (idle-hr-fwd--add)'),
 ('death-front-mid','damage','base',False,'death (terminal; 0 transitions)'),
 # optional
 ('crouch-change','locomotion','upper_additive',True,'additive stand^crouch/crouch^stand (#8390fa57 -> stand^crouch--add -> actor_b-p-stand^crouch--add); 0 incoming, self-loop'),
 ('quick-turn-180-r','locomotion','base',True,'Actor_B 180 turn available via this state (melee-fist-idle-turn-180-r -> actor_b-p-stealth-idle-turn-180)'),
 ('idle^vault-1m','traversal','base',True,'vault 1m from idle'),
 ('move^vault-1m','traversal','base',True,'vault 1m while moving'),
 ('vault-1m^idle','traversal','base',True,'vault exit to idle'),
 ('vault-1m^run','traversal','base',True,'vault exit to run'),
 ('vault-1m^run-a','traversal','base',True,'intermediate vault exit (auto at phase>=0.48 -> vault-1m^run)'),
]
NAMES=[x[0] for x in SEL]
SET=set(NAMES)

# ---------------- runtime fields (from lambda disassembly) ----------------
FIELDS={
 'f32@+120':dict(godot_param='move_speed',tests=['> 0.0','<= 0.0'],meaning='desired/actual move speed; >0 moving (INFERRED meaning, comparisons PROVEN)'),
 'f32@+124':dict(godot_param='turn_delta_deg',tests=['abs() > 135'],meaning='angle between facing and desired heading, degrees (INFERRED); >135 selects 180 turn'),
 'i32@+128':dict(godot_param='use_transition_anims',tests=['truthy'],meaning='gate that chooses start/stop clips vs direct loop entry (INFERRED from paired lambdas 0x47e20/0x47a84, 0x4784c/0x478b0, 0x48688/0x48588)'),
 'i32@+132':dict(godot_param='loco_enabled',tests=['truthy'],meaning='locomotion allowed / grounded gate (INFERRED)'),
 'i32@+136':dict(godot_param='crouch_change_pending',tests=['> 0'],meaning='only gate into crouch-change-idle^idle (INFERRED)'),
 'i32@+140':dict(godot_param='aim_flag_140',tests=['truthy'],meaning='chooses 0.5s vs 0.25s fade on aim change-move-mode (meaning unknown)'),
 'f32@+144':dict(godot_param='move_dir_deg',tests=['abs() <= 90','abs() > 90','abs() > 97.5','abs() < 82.5'],meaning='move direction relative to facing, degrees; fw family if <=90, bw family if >90; 7.5 deg hysteresis when switching while moving (constants PROVEN)'),
 'f32@+148':dict(godot_param='cover_side',tests=['< 0','> 0'],meaning='cover only (excluded)'),
 'f32@+160':dict(godot_param='idle_turn_deg',tests=['> 10','< -10','< 5','> -5'],meaning='in-place turn request angle; >10 -> idle-turn-l, <-10 -> idle-turn-r; exit when back inside +-5 (constants PROVEN; sign->side INFERRED from state names)'),
}
def godot_expr(fid):
    s=summarize(fid)
    rep={'float32[(pointer32[arg0] + 120)]':'move_speed','float32[(pointer32[arg0] + 124)]':'turn_delta_deg',
         'int32[(pointer32[arg0] + 128)]':'use_transition_anims','int32[(pointer32[arg0] + 132)]':'loco_enabled',
         'int32[(pointer32[arg0] + 136)]':'crouch_change_pending','int32[(pointer32[arg0] + 140)]':'aim_flag_140',
         'float32[(pointer32[arg0] + 144)]':'move_dir_deg','float32[(pointer32[arg0] + 148)]':'cover_side',
         'float32[(pointer32[arg0] + 152)]':'cover_f152','float32[(pointer32[arg0] + 160)]':'idle_turn_deg'}
    for k,v in rep.items(): s=s.replace(k,v)
    # compile AND/ORSKIP/RET chain into boolean
    import re
    toks=re.findall(r'(AND|ORSKIP|RET)\[(.*?)\](?= AND| ORSKIP| RET|$)',s)
    if s.startswith('RET '):
        e=s[4:]
    elif toks:
        terms=[]
        for kind,x in toks:
            if kind=='AND': terms.append(x)
            elif kind=='ORSKIP':
                # not(1) -> no skip, keep following RET; not(0) -> short-circuit true
                if x.strip()=='not(0)': terms.append('true'); break
            elif kind=='RET': terms.append(x)
        e=' and '.join(t for t in terms if t!='true') or 'true'
    else: e=s
    e=e.replace('abs(','absf(').replace('float(','float(').replace('not(','not (')
    return e

# ---------------- state records ----------------
def cb_info(s):
    out={}
    for k,v in s['callbacks'].items():
        f=F.get(v,{})
        role={'0x00000024':'start_phase_cb','0x00000028':'phase_update_cb','0x0000002c':'int_flag_cb'}.get(k,k)
        out[role]={'id':v,'expr':f.get('straight_line_return') or ('branched; consts='+','.join(c['interpretation'] for c in f.get('constants',{}).values()))}
    return out

def resolve_state_clips(s,group):
    leaves=sorted(set(clips(s['tree'])))
    res={}
    ctxs={}
    if group in ('locomotion',):
        ctxs={m:sets for m,sets in MODES.items()}
        if s['name']=='crouch-change-idle^idle':
            ctxs={'stand_to_crouch':['anim-overlay-player-crouch-change-stand^crouch'],'crouch_to_stand':['anim-overlay-player-crouch-change-crouch^stand']}
        if s['name']=='crouch-change':
            ctxs={'stand_to_crouch':['anim-overlay-player-crouch-change-stand^crouch'],'crouch_to_stand':['anim-overlay-player-crouch-change-crouch^stand']}
    elif group in ('aim','weapon'):
        ctxs=WEAP
    else:
        ctxs={'default':[]}
    for c,sets in ctxs.items():
        r={}
        for leaf in leaves:
            ch=resolve_fix(leaf,sets+[AB])
            fin=ch[-1]
            ib=info('Actor_B',fin)
            r[leaf]={'chain':ch,'actor_b_clip':fin if ib else None,'actor_b':ib,
                     'actor_a':info('Actor_A',leaf)}
        res[c]=r
    return leaves,res

states=[]
for name,group,layer,opt,note in SEL:
    s=BYNAME[name]
    leaves,res=resolve_state_clips(s,group)
    kept=[t for t in s['transitions'] if t['target'] in SET]
    incoming=sum(1 for x in S for t in x['transitions'] if t['target']==name and x['name']!=name)
    incoming_sub=sum(1 for x in S if x['name'] in SET for t in x['transitions'] if t['target']==name and x['name']!=name)
    states.append(dict(
        name=name,state_offset=s['offset'],record_kind=s['record_kind'],tree=s['tree'],reference_clip=s['reference_clip'],
        category=s['category'],group=group,godot_layer=layer,optional=opt,
        transition_count_total=len(s['transitions']),transition_count_in_subgraph=len(kept),
        incoming_total=incoming,incoming_from_subgraph=incoming_sub,
        entered_by='graph' if incoming>0 else 'code (no incoming transition record in the whole graph)',
        clip_leaves=leaves,callbacks=cb_info(s),resolved_clips=res,note=note))

# ---------------- transitions ----------------
def conds(t):
    out=[]
    for i,c in enumerate(t['conditions']):
        r=[x['hex'] for x in c['raw']]
        k=int(r[0],16); lo=f32(r[1]); hi=f32(r[2])
        d={'index':i,'record_offset':c['offset'],'type':c['type'],'mode':k,
           'min':lo if k&2 else None,'max':hi if k&1 else None}
        if len(r)>3:
            d['flags_word']=r[3]
            sel=int(r[3],16)>>16
            d['variable']={0:'phase (normalized 0..1)',1:'frames? (INFERRED: values 10/40 >1, 0x0001 selector)',6:'unknown selector 6 (picks L vs R 180 turn)'}.get(sel,f'selector {sel}')
        else:
            d['variable']='phase (normalized 0..1)' if i==0 and (lo<=1.0 and hi<=1.0) else ('frames? (value >1, INFERRED)' if i==0 else 'secondary variable (INFERRED: e.g. move-direction degrees on land->run)')
        if c.get('callback'):
            d['lambda']=c['callback']; d['lambda_disasm_summary']=summarize(c['callback']); d['lambda_godot_expr']=godot_expr(c['callback'])
        out.append(d)
    return out
trans=[]
for name in NAMES:
    s=BYNAME[name]
    for i,t in enumerate(s['transitions']):
        if t['target'] not in SET: continue
        rw=[x['hex'] for x in t['raw']]
        c0=t['conditions'][0] if t['conditions'] else None
        at_end = bool(c0 and not c0.get('callback') and int(c0['raw'][0]['hex'],16)==2 and f32(c0['raw'][1]['hex'])>=1.0 and len(t['conditions'])==1)
        trans.append(dict(
            source=name,request=t['request'],target=t['target'],order_in_source=i,record_offset=t['offset'],
            fade_s=round(t['scalar_0x1c'],4),scalar_0x20=round(t['scalar_0x20'],4),
            start_phase_0x24=f32(rw[9]) if rw[9]!='00000000' else None,
            flags_0x04=rw[1],byte_0x28=rw[10][:2],
            conditions=conds(t),
            godot=dict(
                advance='auto' if t['request']=='auto' else 'request:'+t['request'],
                switch_mode='at_end' if at_end else 'immediate',
                xfade_time=round(t['scalar_0x1c'],4),priority=i,
                reset=True)))
dropped=collections.Counter()
for name in NAMES:
    for t in BYNAME[name]['transitions']:
        if t['target'] not in SET: dropped[t['target']]+=1

# code-driven entries (PROPOSED: not in data)
code_entries=[
 dict(to='aim-idle',from_='idle / idle-turn-* / run-fw^idle (not moving)',fade_s=0.2,status='PROPOSED',basis="no incoming record to aim-idle from locomotion; all 38 'aim' request records (cover->cover-*^aim-idle) use 0.2"),
 dict(to='aim-run-forward',from_='run-fw / idle^run-fwd (moving, |move_dir|<=90)',fade_s=0.2,status='PROPOSED',basis='same as above; aim-idle->aim-run-forward request fade 0.2 in data'),
 dict(to='aim-run-backward',from_='run-bkwd / idle^run-bkwd',fade_s=0.3,status='PROPOSED',basis='aim-run-forward->aim-run-backward request fade 0.3 in data'),
 dict(to='run-jump-long',from_='run-fw / idle^run-fwd',fade_s=0.1,status='PROPOSED',basis='0 incoming records; takeoff clip 0.2s long so fade must be short'),
 dict(to='pre-fall',from_='any grounded locomotion',fade_s=0.2,status='PROPOSED',basis='0 incoming; fall entries in data use 0.0-0.2 (vault^fall 0.0, auto-drop-fall-run 0.2)'),
 dict(to='fall',from_='jump-long (airborne longer than clip)',fade_s=0.2,status='PROPOSED',basis='jump-long has only an idle-request exit (0.1) in data'),
 dict(to='fall-land-soft-idle|fall-land-soft-run|fall-land-hard-idle|fall-land-hard-run',from_='fall',fade_s=0.1,status='PROPOSED',basis='0 incoming except wall-jump-fail-* (request fall, fade 0.1)'),
 dict(to='jump-long-land-run',from_='jump-long',fade_s=0.1,status='PROPOSED',basis="jump-long->jump-long-land-idle uses request 'idle' fade 0.1 at phase>=0.9"),
 dict(to='hit-reaction-full-body',from_='idle/locomotion',fade_s=0.1,status='PROPOSED',basis='0 incoming records'),
 dict(to='death-front-mid',from_='any',fade_s=0.2,status='PROPOSED',basis='0 incoming, 0 outgoing records'),
 dict(to='fire|reload*|draw/holster*|hit-reaction-par',from_='upper layer (OneShot / sub state machine)',fade_s=None,status='PROPOSED',basis='partial states have 0 transitions (except reload chain and self-loops); played by gameplay code on an arms/additive layer'),
]

meta=dict(
 source='source/player_blending/player_blending.json (read-only)',
 provenance='extracted & converted player animation graph; neutral aliases; hex ids are opaque keys (not recomputed)',
 units=dict(fade_s='transition scalar +0x1c; interpreted as seconds (INFERRED, supported: 17 distinct values 0..2.0; self-loop auto@phase>=1 uses 0.0 in 151/156; fade <= target clip length in 1221/1228 records)',
            scalar_0x20='second duration, <= fade in 619/625 non-negative records; -1 = unset in 2612/3237; meaning unverified (candidate: motion/root blend time)',
            start_phase_0x24='destination start phase (INFERRED: aim-idle-rotate restarts itself at 1.0 when phase<=0; vault entries 0.75/0.8)',
            byte_0x28='02 default (2997), 04 (151), 05 (89); candidate blend-curve enum (unverified)',
            condition_mode='bitmask: 2=min (>=), 1=max (<=), 3=range, 0=always (PROVEN from value patterns)'),
 evaluation_order='transitions listed in source order; paired lambdas (with/without use_transition_anims) only make sense as first-match-wins -> Godot priority = order_in_source (INFERRED)',
 overlay_resolution='clip names resolved by repeated substitution passes over overlay sets in ascending layer priority (move/crouch/weapon* then actor_b), fixpoint; order INFERRED, not proven',
 modes=MODES,weapons=WEAP,
 counts=dict(states=len(states),core_states=sum(1 for s in states if not s['optional']),transitions_kept=len(trans),transitions_dropped_to_outside=sum(dropped.values()),dropped_targets=dropped.most_common()),
)
RUNTIME_CLIPS={
 'fire':{'status':'INFERRED (reverse lookup of overlay remaps; state leaf is a placeholder \'idle\' overridden by clip callback)',
   'pistol':['9mm-aim-fire','actor_b-p-pistol-fire--add','actor_b-p-pistol-beretta-fire--add'],
   'musket':['2lg-shotgun-fire','bolt-rifle-fire--add','actor_b-p-rifle-idle-aim-fire--add'],
   'bow':['#be1bfc74','actor_b-p-bow-fire--add']},
 'hit-reaction-full-body':{'status':'INFERRED (clip callback returns int32[info+280]; directional Actor_B clips exist)',
   'candidates':['actor_b-p-hr-fw','actor_b-p-hr-bw','actor_b-p-hr-lt','actor_b-p-hr-rt']},
}
for st in states:
    if st['name'] in RUNTIME_CLIPS: st['runtime_clip_candidates']=RUNTIME_CLIPS[st['name']]
meta['godot_notes']=dict(
 base_state_machine='locomotion+air+aim+damage states; each graph state -> AnimationNodeStateMachine state whose tree is a per-move-mode clip set (overlay = which clip set), selected by a mode parameter',
 move_mode_change="request 'change-move-mode': self-transition fade 0.5 (flags 0x82) on idle/run-fw/run-bkwd/starts; 0.25/0.5 on aim states; goes to crouch-change-idle^idle (0.2) when crouch_change_pending. Overrides from movement_transitions: crouch-sprint->walk-crouched 1.0, run-stealth/run-combat/walk-stealth->walk-crouched 0.3, all->evade-stance 0.2",
 phase_gates="condition min 1.0 with no lambda -> switch_mode AT_END; other phase gates -> advance_expression using playback position/length exposed from a script",
 upper_layer='weapon states (fire/reload/draw/holster/hit-reaction-par) have 0 or only internal transitions; drive them from gameplay code on an arms-filtered OneShot/sub-state-machine (partial) or Add2 (additive twins *-add)',
 priorities='use order_in_source as AnimationNodeStateMachineTransition.priority (first match wins)')
json.dump(dict(meta=meta,runtime_fields=FIELDS,states=states,transitions=trans,code_driven_entries_proposed=code_entries,
               movement_mode_transition_overrides=D['movement_transitions']),open(OUT,'w'),indent=1)
print('wrote',OUT,len(states),'states',len(trans),'transitions')
print(meta['counts'])
