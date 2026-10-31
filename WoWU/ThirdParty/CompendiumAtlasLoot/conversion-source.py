from pathlib import Path
import re,json,shutil
src=Path(__file__).with_name('original-data.lua').read_text(encoding='utf-8-sig')
out=[]
for match in re.finditer(r'^data\["([^"]+)"\] = \{[^\n]*\n(.*?)^\}',src,re.M|re.S):
 key,block=match.groups();head=block.split('\titems = {')[0]
 def num(field,s):
  m=re.search(r'\b'+field+r'\s*=\s*(\d+)',s);return int(m[1]) if m else None
 expr=re.search(r'^\tname\s*=\s*(.*)',head,re.M)
 expr=expr[1] if expr else ''
 strings=re.findall(r'"([^"]+)"',expr)
 name=' - '.join(strings) if strings else re.sub(r'(?<=[a-z])(?=[A-Z])',' ',key)
 area=re.search(r'C_Map.GetAreaInfo\((\d+)\)',expr)
 cat='World Bosses' if key=='WorldBosses' else 'Raids' if re.search(r'ContentType\s*=\s*\w*RAID',head) else 'Dungeons'
 row={'id':key,'name':name,'category':cat,'expansion':'Forever','bosses':[]}
 for field in ['InstanceID']:
  v=num(field,head)
  if v:row['instanceID']=v
 if area:row['areaID']=int(area[1])
 levels=re.search(r'LevelRange\s*=\s*(?:GetForVersion\()?\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',head)
 if levels:row['levels']=[int(v) for v in levels.groups()]
 for b in re.finditer(r'^\t\t\{[^\n]*\n(.*?)^\t\t\},',block,re.M|re.S):
  bb=b[1];nm=re.search(r'^\t\t\tname\s*=\s*(.*)',bb,re.M)
  if not nm:continue
  names=re.findall(r'"([^"]+)"',nm[1]);bn=' - '.join(names)
  if not bn or 'updated' in bn.lower() or 'coming' in bn.lower():continue
  if 'TableType = SET_ITTYPE' in bb or 'IgnoreAsSource = true' in bb:continue
  boss={'name':bn,'items':[]}
  npc=num('npcID',bb)
  if npc:boss['npcID']=npc
  if 'specialType = "rare"' in bb:boss['rare']=True
  seen=set()
  for it in re.finditer(r'^\t\t\t\t\{\s*\d+\s*,\s*(\d+)\s*[,}]([^\n]*)',bb,re.M):
   item=int(it[1]);tail=it[2]
   if item in seen:continue
   seen.add(item)
   comment=tail.split('--',1)[1].strip() if '--' in tail else ''
   comment=re.sub(r'^\{FOREVER\}\s*','',comment)
   boss['items'].append({'id':item,'name':comment or 'Item '+str(item)})
  if boss['items']or npc:row['bosses'].append(boss)
 out.append(row)
def lua(v):
 if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
 if isinstance(v,bool):return 'true' if v else 'false'
 if isinstance(v,(int,float)):return str(v)
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
repo=Path(__file__).resolve().parents[3]
p=repo/'WoWU/CompendiumData.lua'
p.write_text('-- Adapted 2026-10-21 from AtlasLoot Classic Forever 1.2.6 (Sliccer and AtlasLoot contributors).\n-- GPL-2.0; original source and licence: ThirdParty/CompendiumAtlasLoot/.\n-- Reference snapshot, not a guarantee of current phase availability. Drop rates omitted.\nif not WoWUClient.isForever then return end\nWoWUCompendiumData={\n'+',\n'.join(lua(r) for r in out)+'\n}\n',encoding='utf-8')
d=Path(__file__).resolve().parent
(d/'ATTRIBUTION.txt').write_text('AtlasLoot Classic Forever 1.2.6-181026-16001, Sliccer and AtlasLoot contributors.\nSource: https://www.curseforge.com/wow/addons/atlasloot-forever/files/9244923\nGPL-2.0. Original data retained here; adapted into CompendiumData.lua on 2026-10-21.\nOnly named instance/encounter records and direct item IDs are included.\nSet/reputation exchanges and conditional phase mutations are not imported.\nDrop percentages lack Forever-specific verification and are not displayed.\nThe source includes future-phase content; availability is not guaranteed.\n',encoding='utf-8')
print('Imported records:',len(out),'encounters:',sum(len(x['bosses'])for x in out),'loot references:',sum(len(b['items'])for x in out for b in x['bosses']))
