"""Measure unique floor and shortest detours on the exported native layout.
Run Godot tools/audit-secondwood.gd first. Grid evidence supplements native
controller sweeps; it is not a human navigation or frame-rate measurement.
"""
import json, heapq, math
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1]
data=json.loads((root/'docs/secondwood-layout-data.json').read_text())
b=int(data['bounds']); shape=(2*b+1,2*b+1)
x,z=np.meshgrid(np.arange(-b,b+1),np.arange(-b,b+1),indexing='ij')
def floor(flags, exclude=None):
    walk=np.zeros(shape,dtype=bool)
    for c in data['clearings']:
        if not set(c['requires'])<=flags: continue
        cx,cz=c['position'];walk|=(x-cx)**2+(z-cz)**2<=c['radius']**2
    for r in data['routes']:
        if r['id']==exclude or not set(r['requires'])<=flags:continue
        for (ax,az),(bx,bz) in zip(r['points'],r['points'][1:]):
            dx,dz=bx-ax,bz-az
            t=np.clip(((x-ax)*dx+(z-az)*dz)/(dx*dx+dz*dz),0,1)
            walk|=(x-ax-t*dx)**2+(z-az-t*dz)**2<=data['corridor_radius']**2
    return walk
moves=[(a,c,math.hypot(a,c)) for a in [-1,0,1] for c in [-1,0,1] if a or c]
def shortest(walk,start,end):
    start=tuple(int(round(v))+b for v in start);end=tuple(int(round(v))+b for v in end)
    dist={start:0}; queue=[(0,start)]
    while queue:
        d,p=heapq.heappop(queue)
        if p==end:return d
        if d!=dist[p]:continue
        for dx,dz,cost in moves:
            q=(p[0]+dx,p[1]+dz)
            if not (0<=q[0]<shape[0] and 0<=q[1]<shape[1]) or not walk[q]:continue
            # Prevent diagonals from cutting an unwalkable corner.
            if dx and dz and not (walk[p[0]+dx,p[1]] and walk[p[0],p[1]+dz]):continue
            nd=d+cost
            if nd<dist.get(q,math.inf):dist[q]=nd;heapq.heappush(queue,(nd,q))
    return None
flags=set(data['all_flags']);opened=floor(flags)
records=[]
for r in data['routes']:
    if not r['shortcut']:continue
    # Measure the link independently with every other route available.
    before=shortest(floor(flags,r['id']),r['points'][0],r['points'][-1])
    after=shortest(opened,r['points'][0],r['points'][-1])
    saving=None if before is None else 1-after/before
    records.append(dict(id=r['id'],endpoints=[r['points'][0],r['points'][-1]],requires=r['requires'],before=before,after=after,saving=saving))
failures=[r['id'] for r in records if r['before'] is None or r['after'] is None or r['saving']<0.4]
report=dict(status='failed' if failures else 'passed', failures=failures, area=data['area'],area_ratio=data['area']/32400,route_length=data['length'],route_ratio=data['length']/1068.8615,walkable_unit_grid_cells=int(opened.sum()),initial_walkable_unit_grid_cells=int(floor(set()).sum()),shortcuts=records,scope='Eight-neighbor one-unit raster shortest floor paths with diagonal corner protection. Before excludes only this shortcut, keeping every other route and capability open. Raster distances approximate walking, not centerline graph distances.')
(root/'docs/secondwood-shortcut-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))

assert not failures, "Shortcut savings below 40 percent: "+str(failures)
