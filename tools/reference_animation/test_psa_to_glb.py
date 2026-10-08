"""Regression tests for the conversion failure exposed by rendered validation."""
import json,math,struct,tempfile,unittest
from pathlib import Path
import numpy as np
from psa_to_glb import convert

class ConversionTests(unittest.TestCase):
 def fixture(self,root,missing=False,baked_scale=1):
  bones=[dict(name='root',parent=-1,translation=[0,0,0],rotation=[0,0,0,1],scale=[baked_scale,baked_scale,baked_scale]),dict(name='pelvis',parent=0,translation=[0,0,100],rotation=[0,math.sqrt(.5),0,-math.sqrt(.5)],scale=[1,1,1])]
  names=b''.join(b['name'].encode().ljust(64,b'\0')+bytes(56) for b in bones)
  info=b'Test'.ljust(64,b'\0')+bytes(64)+struct.pack('<iiiifffiii',2,0,0,0,0,1,30,0,0,1)
  keys=np.array([[0,0,0,0,0,0,-1,1],[0,0,100,0,math.sqrt(.5),0,math.sqrt(.5),1]],dtype='<f4')
  if missing:keys[1]=[0,0,0,0,0,0,-1,1]
  def chunk(tag,size,n,data):return struct.pack('<20siii',tag.encode(),0,size,n)+data
  p=root/'Test.psa';p.write_bytes(chunk('BONENAMES',120,2,names)+chunk('ANIMINFO',168,1,info)+chunk('ANIMKEYS',32,2,keys.tobytes()))
  if missing:p.with_suffix('.config').write_text('[RemoveTracks]\nTest.1=all\n')
  output=root/'Test.glb';convert(p,'SourceSkeleton',bones,output);data=output.read_bytes();length=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+length]);binary=data[28+length:]
  def accessor(i):
   a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];return np.frombuffer(binary[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']],'<f4')
  return g,accessor
 def test_missing_tracks_restore_reference_transform(self):
  with tempfile.TemporaryDirectory() as d:
   g,acc=self.fixture(Path(d),True);sam=g['animations'][0]['samplers'];self.assertTrue(np.allclose(acc(sam[2]['output']),[0,1,0]));self.assertTrue(np.allclose(acc(sam[3]['output']),g['nodes'][1]['rotation']))
 def test_rotation_basis_matches_rest_and_stands_upright(self):
  with tempfile.TemporaryDirectory() as d:
   g,acc=self.fixture(Path(d));self.assertEqual(g['nodes'][1]['scale'],[1,1,1]);q=acc(g['animations'][0]['samplers'][3]['output']);rest=g['nodes'][1]['rotation'];self.assertAlmostEqual(abs(float(np.dot(q,rest))),1,places=5)
   # Pelvis' local +X (spine direction) must become +Y, not point down.
   x,y,z,w=q;self.assertGreater(float(2*(x*y+w*z)),.99)
 def test_prebaked_scale_is_not_applied_twice(self):
  with tempfile.TemporaryDirectory() as d:
   g,acc=self.fixture(Path(d),baked_scale=2);self.assertEqual(g['nodes'][0]['scale'],[1,1,1]);self.assertTrue(np.allclose(acc(g['animations'][0]['samplers'][2]['output']),[0,1,0]))
 def test_source_attribution_survives_conversion(self):
  with tempfile.TemporaryDirectory() as d:
   g,_=self.fixture(Path(d));self.assertIn('third-party',g['asset']['extras']['source']);self.assertEqual(len(g['asset']['extras']['psa_sha256']),64)
if __name__=='__main__':unittest.main()
