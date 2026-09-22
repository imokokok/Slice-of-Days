"""Convert Chandra's supplied VTK surfaces to GLB without inventing depth.
Run at project root. Positions, component registration and normals are retained;
triangle strips are triangulated. Colours label layers, not visible-light colour.
"""
from pathlib import Path
import json, struct, zipfile, re, hashlib
folder=Path('extensions/observatory/assets/nebulae')
source=folder/'casa_observed.zip'
colours={'cco':[1,.94,.72,1], 'fekcorr':[.92,.37,.29,1], 'newar':[.42,.79,.9,1], 'newhetg':[.66,.9,.75,1], 'newjets':[.55,.64,1,1], 'newopt':[1,.81,.46,1], 'newsi':[.51,.65,.96,1]}
binary=bytearray(); views=[]; accessors=[]; meshes=[]; materials=[]; nodes=[]; counts={}
def data_accessor(values,kind,ctype,count,components):
    while len(binary)%4: binary.append(0)
    offset=len(binary); code='f' if ctype==5126 else 'I'
    binary.extend(struct.pack('<'+code*len(values),*values))
    views.append({'buffer':0,'byteOffset':offset,'byteLength':len(binary)-offset})
    a={'bufferView':len(views)-1,'componentType':ctype,'count':count,'type':kind}
    if kind=='VEC3':
        a['min']=[min(values[i::3]) for i in range(3)]; a['max']=[max(values[i::3]) for i in range(3)]
    accessors.append(a); return len(accessors)-1
with zipfile.ZipFile(source) as z:
    for name in sorted(z.namelist()):
        if not name.endswith('.vtk'): continue
        text=z.read(name).decode('ascii'); tokens=text.split(); pi=tokens.index('POINTS'); n=int(tokens[pi+1])
        points=list(map(float,tokens[pi+3:pi+3+3*n])); si=tokens.index('TRIANGLE_STRIPS'); strips=int(tokens[si+1]); cursor=si+3; triangles=[]
        for _ in range(strips):
            length=int(tokens[cursor]); strip=list(map(int,tokens[cursor+1:cursor+1+length])); cursor+=length+1
            for j in range(length-2):
                tri=[strip[j],strip[j+1],strip[j+2]] if j%2==0 else [strip[j+1],strip[j],strip[j+2]]
                if len(set(tri))==3: triangles.extend(tri)
        attributes={'POSITION':data_accessor(points,'VEC3',5126,n,3)}
        # The supplied POINT_DATA normals are already in the same coordinate frame.
        ni=tokens.index('NORMALS',tokens.index('POINT_DATA'))
        normals=list(map(float,tokens[ni+3:ni+3+3*n])); attributes['NORMAL']=data_accessor(normals,'VEC3',5126,n,3)
        idx=data_accessor(triangles,'SCALAR',5125,len(triangles),1)
        stem=Path(name).stem.split('-')[0]; mat=len(materials)
        materials.append({'name':stem,'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':colours[stem],'metallicFactor':0,'roughnessFactor':1}})
        meshes.append({'name':stem,'primitives':[{'attributes':attributes,'indices':idx,'material':mat}]}); nodes.append({'name':stem,'mesh':len(meshes)-1})
        counts[stem]={'vertices':n,'triangles':len(triangles)//3}
    readme=[n for n in z.namelist() if n.endswith('.txt')][0]
    (folder/'CASA_SOURCE_README.txt').write_bytes(z.read(readme))
doc={'asset':{'version':'2.0','generator':'Solmere lossless-coordinate VTK converter','copyright':'NASA, Smithsonian Astrophysical Observatory/Chandra X-ray Center, MIT & T. Delaney et al.'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],'nodes':nodes,'meshes':meshes,'materials':materials,'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors}
j=json.dumps(doc,separators=(',',':')).encode(); j+=b' '*((-len(j))%4); binary+=b'\0'*((-len(binary))%4)
output=struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(binary))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(binary),0x004e4942)+binary
(folder/'casa.glb').write_bytes(output)
(folder/'casa_import_manifest.json').write_text(json.dumps({'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'geometry_policy':'Source positions and inter-layer alignment unchanged. No inferred photo depth. Uniform viewing normalization happens in runtime.','colour_policy':'Schematic layer identity, not natural colour or temperature.','components':counts},indent=2),encoding='utf-8')
print('CASSIOPEIA A:',counts,'GLB bytes',len(output))
