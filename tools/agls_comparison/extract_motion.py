"""Decode the selected uncooked AGLS FK animation channels; never modify source assets."""
import argparse
import base64
import bisect
import hashlib
import json
import math
import struct
from pathlib import Path


def mul(a, b):
    x, y, z, w = a
    X, Y, Z, W = b
    return [w*X+x*W+y*Z-z*Y, w*Y-x*Z+y*W+z*X,
            w*Z+x*Y-y*X+z*W, w*W-x*X-y*Y-z*Z]


def rotate(q, v):
    return mul(mul(q, [*v, 0]), [-q[0], -q[1], -q[2], q[3]])[:3]


def rotator(roll, pitch, yaw):
    # Unreal FRotator::Quaternion: channels are Roll(X), Pitch(Y), Yaw(Z), in degrees.
    sr, sp, sy = [math.sin(math.radians(v)*0.5) for v in (roll, pitch, yaw)]
    cr, cp, cy = [math.cos(math.radians(v)*0.5) for v in (roll, pitch, yaw)]
    return [cr*sp*sy-sr*cp*cy, -cr*sp*cy-sr*cp*sy,
            cr*cp*sy-sr*sp*cy, cr*cp*cy+sr*sp*sy]


def props(row):
    return {x['Name']: x.get('Value') for x in row['Data']}


def skeleton(data):
    exp = next(x for x in data['Exports'] if x['ObjectName'] == 'ALS_Mannequin_Skeleton')
    raw = base64.b64decode(exp['Extras'])
    count, = struct.unpack_from('<i', raw)
    assert count == len(props(exp)['BoneTree']), 'Reference skeleton count differs from BoneTree'
    offset = 4
    bones = []
    for i in range(count):
        idx, suffix, parent, length = struct.unpack_from('<4i', raw, offset)
        offset += 16
        assert suffix == 0 and 0 < length < 256 and -1 <= parent < i
        name = data['NameMap'][idx]
        assert raw[offset:offset+length].rstrip(b'\0').decode() == name
        offset += length
        bones.append({'name': name, 'parent': parent})
    pose_count, = struct.unpack_from('<i', raw, offset)
    offset += 4
    assert pose_count == count
    for i, b in enumerate(bones):
        qx, qy, qz, qw, px, py, pz, sx, sy, sz = struct.unpack_from('<10d', raw, offset+80*i)
        assert abs(qx*qx+qy*qy+qz*qz+qw*qw-1) < 0.0001
        assert max(abs(s-1) for s in (sx, sy, sz)) < 0.001
        b.update(rotation=[qx, qy, qz, qw], position=[px, py, pz])
    assert len({b['name'].lower() for b in bones}) == count
    return bones


def channel(c, time):
    times = [v['Value'] for v in c['Times']]
    keys = c['Values']
    assert len(times) == len(keys)
    if not keys:
        assert c['bHasDefaultValue'], 'Channel has no data or default'
        return float(c['DefaultValue'])
    rate = c['TickResolution']
    frame = time * rate['Numerator'] / rate['Denominator']
    i = bisect.bisect_right(times, frame)-1
    if i < 0:
        return float(keys[0]['Value'])
    if i >= len(keys)-1:
        return float(keys[-1]['Value'])
    assert keys[i]['InterpMode'] == 'RCIM_Linear', 'Unsupported channel interpolation'
    alpha = (frame-times[i])/(times[i+1]-times[i])
    return float(keys[i]['Value'])*(1-alpha)+float(keys[i+1]['Value'])*alpha


def basis(q, scale=(1, 1, 1)):
    return [rotate(q, [scale[j] if i == j else 0 for i in range(3)]) for j in range(3)]


def xform(cols, v):
    return [sum(cols[j][i]*v[j] for j in range(3)) for i in range(3)]


def globals_from_local(bones, locals_):
    out = []
    for i, b in enumerate(bones):
        p, q = locals_[i][:2]
        scale = locals_[i][2] if len(locals_[i]) > 2 else [1, 1, 1]
        cols = basis(q, scale)
        if b['parent'] >= 0:
            parent = out[b['parent']]
            p = [a+c for a, c in zip(parent['position'], xform(parent['basis'], p))]
            cols = [xform(parent['basis'], v) for v in cols]
            q = mul(parent['rotation'], q)
        out.append({'position': p, 'rotation': q, 'basis': cols})
    return out


def to_godot(t):
    # ALS skeleton reference faces +Y, with its left side at +X. Frontier's rig faces +Z.
    x, y, z = t['position']
    qx, qy, qz, qw = t['rotation']
    out = {'position': [x/100, z/100, y/100], 'rotation': [-qx, -qz, -qy, qw]}
    if 'scale' in t:
        out['scale'] = [t['scale'][i] for i in (0, 2, 1)]
    if 'basis' in t:
        out['basis'] = [[t['basis'][j][i] for i in (0, 2, 1)] for j in (0, 2, 1)]
    return out


def decode(data, bones):
    seq = next(e for e in data['Exports'] if isinstance(e.get('Data'), list)
               and 'SequenceLength' in props(e))
    info = props(seq)
    rig = next(e for e in data['Exports'] if e['ObjectName'].startswith('FKControlRig'))
    mode = next(x for x in rig['Data'] if x['Name'] == 'ApplyMode')
    assert mode.get('Value', '').endswith('::Direct'), 'FK controls must directly set local transforms'
    section = next(e for e in data['Exports'] if 'ControlRigParameterSection' in e['ObjectName'])
    params = props(section)['TransformParameterNamesAndCurves']
    channels = {}
    known = {b['name'].lower(): i for i, b in enumerate(bones)}
    for row in params:
        fields = row['Value']
        name = next(x['Value'] for x in fields if x['Name'] == 'ParameterName').removesuffix('_CONTROL').lower()
        assert name in known, 'Unknown FK control: '+name
        d = {}
        for key in ('Translation', 'Rotation', 'Scale'):
            components = [x for x in fields if x['Name'] == key]
            assert len(components) == 3
            d[key] = [x['Value'][0]['Value'] for x in components]
        channels[known[name]] = d
    duration = float(info['SequenceLength'])
    rate = {p['Name']: p['Value'] for p in info.get('SamplingFrameRate', [])}
    assert rate or info.get('ImportResampleFramerate'), 'No native sampling rate available'
    fps = float(rate.get('Numerator', info.get('ImportResampleFramerate'))) / float(rate.get('Denominator', 1))
    frames = round(duration * fps)
    assert abs(frames / fps - duration) < 0.00001
    if 'NumberOfKeys' in info and int(info['NumberOfKeys']) != frames + 1:
        # Some source key-count summaries are stale; the live FK section gives the full range.
        bounds = props(section)['SectionRange'][0]['Value']
        assert bounds['LowerBound']['Value']['Value'] == 0
        assert bounds['UpperBound']['Value']['Value'] == frames, 'FK section does not cover the stated duration'
    # The FK Euler channels can wrap at +/-180 degrees. Recover native frame poses,
    # then let Godot interpolate their quaternions, as skeletal animation keys do.
    times = [i/fps for i in range(frames+1)]
    samples = []
    for time in times:
        local = [(b['position'], b['rotation'], [1, 1, 1]) for b in bones]
        for idx, d in channels.items():
            p = [channel(c, time) for c in d['Translation']]
            q = rotator(*[channel(c, time) for c in d['Rotation']])
            scale = [channel(c, time) for c in d['Scale']]
            assert all(math.isfinite(s) and s > 0 for s in scale), 'Invalid FK scale'
            local[idx] = p, q, scale
        samples.append({'time': min(time, duration), 'local': [to_godot({'position': p, 'rotation': q, 'scale': scale}) for p, q, scale in local],
                        'global': [to_godot(t) for t in globals_from_local(bones, local)]})
    return {'name': seq['ObjectName'], 'length': duration, 'control_count': len(channels), 'native_sample_rate': fps, 'source_number_of_keys': info.get('NumberOfKeys'), 'samples': samples}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--reader-json', type=Path, required=True)
    ap.add_argument('--extraction', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    original = json.loads((args.reader_json/'skeleton.json').read_text())
    bones = skeleton(original)
    records = json.loads((args.extraction/'animation_assets.json').read_text())
    lookup = {Path(x['path']).stem: x for x in records}
    rest_global = globals_from_local(bones, [(b['position'], b['rotation']) for b in bones])
    skeleton_rows = []
    for b, g in zip(bones, rest_global):
        skeleton_rows.append({'name': b['name'], 'parent': b['parent'],
                              'rest': to_godot(b), 'global_rest': to_godot(g)})
    clips = []
    for file in sorted(args.reader_json.glob('*.json')):
        if file.stem in ('skeleton', 'target_skeleton'):
            continue
        data = json.loads(file.read_text())
        if 'Exports' not in data:
            continue
        clip = decode(data, bones)
        record = lookup[clip['name']]
        src = args.extraction/'UnrealProject'/record['path']
        clip.update(source_path=record['path'], source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),
                    source_attribution='AGLS supplied Unreal project; individual clip authorship is not inferred from its folder')
        clips.append(clip)
        print(clip['name'], clip['length'], 'seconds;', clip['control_count'], 'controls;', len(clip['samples']), 'samples')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    payload = {'decoder': 'UAssetAPI 1.1.0 + native FK Direct controls at original frame poses; quaternion interpolation in Godot',
               'source_modified': False, 'coordinate_mapping': 'ALS skeleton cm (X,Y,Z) to Frontier metres (X,Z,Y)',
               'bones': skeleton_rows, 'clips': clips}
    args.output.write_text(json.dumps(payload, separators=(',', ':'))+'\n')
    print('Decoded', len(clips), 'clips; output', args.output.stat().st_size, 'bytes')


if __name__ == '__main__':
    main()
