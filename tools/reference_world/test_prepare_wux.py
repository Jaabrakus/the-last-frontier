import hashlib
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from prepare_wux import prepare, validate_wux


class SafeUnpackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wux-unpack-test-',dir='/private/tmp')
        self.root = Path(self.temp.name)
        # Small but structurally valid WUX; zero padding is valid and is not a corruption test.
        header=struct.pack('<IIIIQQ',0x30585557,0x1099d02e,512,0,512,0)
        self.data=(header+struct.pack('<I',0)).ljust(512,b'\0')+bytes(range(256))*2
        self.source=self.root/'fixture.wux';self.source.write_bytes(self.data)
        self.archive=self.root/'fixture.7z'
        subprocess.run(['bsdtar','--format=7zip','-cf',str(self.archive),'-C',str(self.root),'fixture.wux'],check=True)
        self.output=self.root/'output/recovered.wux'

    def tearDown(self):
        self.temp.cleanup()

    def test_full_roundtrip_and_refuse_overwrite(self):
        record=prepare(self.archive,self.output,expected_sha256=hashlib.sha256(self.data).hexdigest(),reserve=0)
        self.assertTrue(record['verified'])
        self.assertEqual(self.output.read_bytes(),self.data)
        self.assertTrue(self.output.with_suffix('.wux.verified.json').exists())
        with self.assertRaisesRegex(ValueError,'already exists'):prepare(self.archive,self.output,reserve=0)
        self.assertEqual(self.output.read_bytes(),self.data)

    def test_mismatched_hash_does_not_publish(self):
        with self.assertRaisesRegex(ValueError,'SHA-256'):
            prepare(self.archive,self.output,expected_sha256='0'*64,reserve=0)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.output.parent.glob('*.partial')),[])
        self.assertTrue(self.archive.exists())

    def test_no_space_does_not_start_output(self):
        usage=shutil._ntuple_diskusage(total=1000,used=1000,free=0)
        with patch('prepare_wux.shutil.disk_usage',return_value=usage):
            with self.assertRaisesRegex(ValueError,'Need'):prepare(self.archive,self.output,reserve=0)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.output.parent.glob('*.partial')),[])

    def test_space_loss_midstream_cleans_partial(self):
        ample=shutil._ntuple_diskusage(total=100000,used=0,free=100000)
        empty=shutil._ntuple_diskusage(total=100000,used=100000,free=0)
        with patch('prepare_wux.shutil.disk_usage',side_effect=[ample,empty]):
            with self.assertRaisesRegex(OSError,'reserve'):
                prepare(self.archive,self.output,reserve=0)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.output.parent.glob('*.partial')),[])
        self.assertTrue(self.archive.exists())

    def test_missing_sector_is_rejected(self):
        self.source.write_bytes(self.data[:32]+struct.pack('<I',10)+self.data[36:])
        with self.assertRaisesRegex(ValueError,'missing data'):validate_wux(self.source)

    def test_truncated_index_is_rejected(self):
        self.source.write_bytes(self.data[:33])
        with self.assertRaisesRegex(ValueError,'Short WUX index'):validate_wux(self.source)


if __name__=='__main__':unittest.main()
