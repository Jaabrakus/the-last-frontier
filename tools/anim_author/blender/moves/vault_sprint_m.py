"""The sprint vault for the other hand: the right hand planted, the legs sweeping to the character's left (the mirror of vault_sprint, then
optimized on its own: the mirrored native's run arms are not the same as the original's)."""
import rigkit
from . import vault_sprint as base
NATIVE = base.NATIVE
MIRROR = True
SPEC = rigkit.mirror_spec(base.SPEC)
rigkit.load_keys(SPEC, __file__)
shape = base.shape
params = base.params
