#!/usr/bin/env python3
"""Fit an attributed reference GLB to the existing Actor_B bind skeleton, offline.

This produces isolated visual probes, not production characters or animation
retargets. Joint-to-child anatomical frames replace incompatible native bone
axes. Unknown weighted bones use an explicitly recorded mapped ancestor.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

from convert_character_mesh import Gltf


COMPONENTS = {5120: 'i1', 5121: 'u1', 5122: '<i2', 5123: '<u2', 5125: '<u4', 5126: '<f4'}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


class Glb:
    def __init__(self, path):
        self.path = path
        raw = path.read_bytes()
        magic, version, length = struct.unpack_from('<4sII', raw)
        if magic != b'glTF' or version != 2 or length != len(raw):
            raise ValueError('Invalid GLB header')
        offset = 12
        self.binary = None
        while offset < len(raw):
            size, kind = struct.unpack_from('<I4s', raw, offset)
            data = raw[offset + 8:offset + 8 + size]
            if kind == b'JSON':
                self.document = json.loads(data)
            elif kind == b'BIN\0':
                self.binary = data
            offset += size + 8
        if self.binary is None:
            raise ValueError('Missing embedded GLB buffer')

    def view(self, index):
        v = self.document['bufferViews'][index]
        offset = v.get('byteOffset', 0)
        return self.binary[offset:offset + v['byteLength']]

    def accessor(self, index):
        a = self.document['accessors'][index]
        if 'sparse' in a:
            raise ValueError('Sparse input accessor unsupported')
        v = self.document['bufferViews'][a['bufferView']]
        dtype = np.dtype(COMPONENTS[a['componentType']])
        width = WIDTHS[a['type']]
        stride = v.get('byteStride', dtype.itemsize * width)
        data = np.ndarray((a['count'], width), dtype=dtype, buffer=self.binary,
            offset=v.get('byteOffset', 0) + a.get('byteOffset', 0), strides=(stride, dtype.itemsize)).copy()
        if a.get('normalized'):
            limits = np.iinfo(dtype)
            data = np.maximum(-1, data.astype(float) / limits.max)
        return data


def unit(vector):
    length = np.linalg.norm(vector)
    if length < 1e-9:
        raise ValueError('Degenerate anatomical frame')
    return vector / length


def frame(position, direction, secondary):
    x = unit(direction)
    y = unit(secondary - x * np.dot(x, secondary))
    z = unit(np.cross(x, y))
    result = np.eye(4)
    result[:3, :3] = np.stack((x, y, z), axis=1)
    result[:3, 3] = position
    return result


def target_skeleton(record):
    bones = record['bones']
    globals_ = [np.vstack((np.asarray(b['rest']).reshape(3, 4), [0, 0, 0, 1])) for b in bones]
    by_name = {b['name']: i for i, b in enumerate(bones)}
    if len(by_name) != len(bones):
        raise ValueError('Duplicate target bone names')
    locals_ = [g if b['parent'] is None else np.linalg.inv(globals_[by_name[b['parent']]]) @ g
        for b, g in zip(bones, globals_)]
    return bones, globals_, locals_, by_name


def anatomical_transforms(source_positions, target_positions, mapping):
    """Rest fitting uses semantic landmarks, never raw source/target bone axes."""
    source_children = {'Spine_1': 'Spine_2', 'Spine_2': 'Neck', 'Neck': 'Head'}
    source_previous = {}
    palms = {}
    for side in ('L', 'R'):
        for parent, child in [('Clavicle', 'Arm_1'), ('Arm_1', 'Arm_2'), ('Arm_2', 'Wrist'),
                              ('Leg_1', 'Leg_2'), ('Leg_2', 'Ankle'), ('Ankle', 'Toe')]:
            source_children[parent + '_' + side] = child + '_' + side
        for letter in 'ABCDE':
            source_children[f'Finger_{letter}_1_{side}'] = f'Finger_{letter}_2_{side}'
            source_children[f'Finger_{letter}_2_{side}'] = f'Finger_{letter}_3_{side}'
            source_previous[f'Finger_{letter}_3_{side}'] = f'Finger_{letter}_2_{side}'
        wrist = 'Wrist_' + side
        base_names = [f'Finger_{letter}_1_{side}' for letter in 'BCDE']
        sp = np.mean([source_positions[n] for n in base_names], axis=0) - source_positions[wrist]
        tp = np.mean([target_positions[mapping[n]] for n in base_names], axis=0) - target_positions[mapping[wrist]]
        sl = source_positions[base_names[0]] - source_positions[base_names[-1]]
        tl = target_positions[mapping[base_names[0]]] - target_positions[mapping[base_names[-1]]]
        palms[side] = (sp, tp, sl, tl, unit(np.cross(sp, sl)), unit(np.cross(tp, tl)))
    transforms, details = {}, []
    for name, target_name in mapping.items():
        sp, tp = source_positions[name], target_positions[target_name]
        kind, ratio = 'preserve model facing, translate anchor', 1.0
        ksource, ktarget = np.eye(4), np.eye(4)
        ksource[:3, 3], ktarget[:3, 3] = sp, tp
        child_error = None
        if name.startswith('Wrist_'):
            side = name[-1]
            sd, td, sl, tl, _, _ = palms[side]
            ksource, ktarget = frame(sp, sd, sl), frame(tp, td, tl)
            scales = [np.linalg.norm(td) / np.linalg.norm(sd),
                np.linalg.norm(tl) / np.linalg.norm(sl), np.linalg.norm(tl) / np.linalg.norm(sl)]
            kind = 'wrist-to-finger-base palm frame and length/width fit'
        elif name in source_children or name in source_previous:
            other = source_children.get(name, source_previous.get(name))
            sign = 1.0 if name in source_children else -1.0
            sd = (source_positions[other] - sp) * sign
            td = (target_positions[mapping[other]] - tp) * sign
            ratio = np.linalg.norm(td) / np.linalg.norm(sd)
            if name.startswith('Finger_'):
                secondary_s, secondary_t = palms[name[-1]][4:]
                kind = 'finger segment direction and palm-normal frame'
            else:
                secondary_s = secondary_t = np.array([0., 0., 1.])
                # The ankle/toe vector can be almost forward; an up ray supplies a stable roll.
                if abs(np.dot(unit(sd), secondary_s)) > .95 or abs(np.dot(unit(td), secondary_t)) > .95:
                    secondary_s = secondary_t = np.array([0., 1., 0.])
                kind = 'anatomical chain direction with facing/up roll reference'
            ksource, ktarget = frame(sp, sd, secondary_s), frame(tp, td, secondary_t)
            scales = [ratio, 1., 1.]
        else:
            scales = [1., 1., 1.]
        scale = np.eye(4)
        scale[:3, :3] = np.diag(scales)
        matrix = ktarget @ scale @ np.linalg.inv(ksource)
        if name in source_children:
            other = source_children[name]
            child_error = float(np.linalg.norm((matrix @ np.r_[source_positions[other], 1.])[:3] - target_positions[mapping[other]]))
        anchor_error = float(np.linalg.norm((matrix @ np.r_[sp, 1.])[:3] - tp))
        if np.linalg.det(matrix[:3, :3]) <= 0:
            raise ValueError('Reflected fitting frame for ' + name)
        transforms[name] = matrix
        details.append({'source': name, 'target': target_name, 'method': kind, 'axis_scale': scales,
            'anchor_error_m': anchor_error, 'child_landmark_error_m': child_error})
    return transforms, details


def source_ancestors(glb, joint_nodes):
    parents = {c: i for i, n in enumerate(glb.document['nodes']) for c in n.get('children', [])}
    return parents


def triangle_quality(before, after, triangles):
    def areas(vertices):
        t = vertices[triangles]
        return np.linalg.norm(np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0]), axis=1) * .5
    a, b = areas(before), areas(after)
    ratios = b[a > 1e-12] / a[a > 1e-12]
    return {'minimum_area_ratio': float(ratios.min()), 'median_area_ratio': float(np.median(ratios)),
        'triangles_below_one_percent_source_area': int(np.sum(ratios < .01)),
        'collapsed_triangles': int(np.sum((a > 1e-12) & (b <= 1e-12)))}


def clip_hand_wrist(primitive, source_positions, mapping):
    """Cut hand polygons at each measured wrist plane; interpolate boundary data."""
    fields = {key: list(primitive[key]) for key in ['before', 'position', 'normal', 'joints', 'weights']}
    if primitive['uv'] is not None:
        fields['uv'] = list(primitive['uv'])
    planes = {}
    for side in ('L', 'R'):
        origin = source_positions['Wrist_' + side]
        bases = [source_positions[f'Finger_{letter}_1_{side}'] for letter in 'BCDE']
        planes[side] = (origin, unit(np.mean(bases, axis=0) - origin))
    edge_cache, triangles, discarded_mass = {}, [], 0.

    def crossing(a, b, da, db, side):
        nonlocal discarded_mass
        key = (min(a, b), max(a, b), side)
        if key in edge_cache:
            return edge_cache[key]
        t = da / (da - db)
        index = len(fields['before'])
        for field in ('before', 'position', 'normal', 'uv'):
            if field in fields:
                fields[field].append(np.asarray(fields[field][a]) * (1 - t) + np.asarray(fields[field][b]) * t)
        combined = {}
        for vertex, share in ((a, 1 - t), (b, t)):
            for joint, weight in zip(fields['joints'][vertex], fields['weights'][vertex]):
                if weight > 0:
                    combined[int(joint)] = combined.get(int(joint), 0.) + weight * share
        ordered = sorted(combined.items(), key=lambda item: -item[1])
        discarded_mass = max(discarded_mass, sum(w for _, w in ordered[4:]))
        joints, weights = np.zeros(4, dtype=np.uint16), np.zeros(4)
        for col, (joint, weight) in enumerate(ordered[:4]):
            joints[col], weights[col] = joint, weight
        weights /= weights.sum()
        fields['joints'].append(joints)
        fields['weights'].append(weights)
        edge_cache[key] = index
        return index

    for triangle in primitive['triangles']:
        center = primitive['before'][triangle].mean(axis=0)
        side = 'L' if center[0] >= 0 else 'R'
        origin, direction = planes[side]
        distances = [(float(np.dot(fields['before'][int(i)] - origin, direction)), int(i)) for i in triangle]
        polygon = []
        for edge in range(3):
            da, a = distances[edge]
            db, b = distances[(edge + 1) % 3]
            if da >= -1e-9:
                polygon.append(a)
            if (da >= -1e-9) != (db >= -1e-9):
                polygon.append(crossing(a, b, da, db, side))
        for i in range(1, len(polygon) - 1):
            triangles.append([polygon[0], polygon[i], polygon[i + 1]])
    result = {key: np.asarray(values) for key, values in fields.items()}
    result['triangles'] = np.asarray(triangles, dtype=np.uint32).reshape(-1, 3)
    result['uv'] = result.get('uv')
    result['normal'] /= np.maximum(np.linalg.norm(result['normal'], axis=1, keepdims=True), 1e-12)
    result['name'], result['material'] = primitive['name'], primitive['material']
    result['wrist_crop'] = {'plane': 'through measured source Wrist, normal toward mean finger bases; retain distal side',
        'new_boundary_vertices': len(edge_cache), 'maximum_boundary_weight_discarded': float(discarded_mass),
        'triangles': len(triangles)}
    return result


def fit(source, target_record, semantic_map, output_dir):
    reference = Glb(source)
    source_doc = reference.document
    if len(source_doc['skins']) != 1:
        raise ValueError('Probe expects one unified source skin')
    source_skin = source_doc['skins'][0]
    joint_nodes = source_skin['joints']
    source_names = [source_doc['nodes'][i]['name'] for i in joint_nodes]
    if len(set(source_names)) != len(source_names):
        raise ValueError('Source bone names are not unique')
    source_world = np.linalg.inv(reference.accessor(source_skin['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1))
    source_positions = {n: w[:3, 3] for n, w in zip(source_names, source_world)}
    target = json.loads(target_record.read_text())
    target_bones, target_world, target_local, target_ids = target_skeleton(target)
    target_positions = {n: target_world[i][:3, 3] for n, i in target_ids.items()}
    map_record = json.loads(semantic_map.read_text())
    mapping = {r['source']: r['target'] for r in map_record['mappings']}
    if not set(mapping).issubset(source_positions) or not set(mapping.values()).issubset(target_positions):
        raise ValueError('Semantic map names do not resolve')
    matrices, landmark_report = anatomical_transforms(source_positions, target_positions, mapping)
    parents = source_ancestors(reference, joint_nodes)
    effective, fallback_report = [], []
    for node, name in zip(joint_nodes, source_names):
        current = node
        while current is not None and source_doc['nodes'][current]['name'] not in mapping:
            current = parents.get(current)
        ancestor = source_doc['nodes'][current]['name'] if current is not None else 'Skl_Root'
        effective.append(ancestor)
        if ancestor != name:
            fallback_report.append({'source': name, 'mapped_source_ancestor': ancestor, 'target': mapping[ancestor],
                'method': 'retain geometry relative to mapped ancestor; collapse unsupported motion weights'})
    all_matrices = np.asarray([matrices[n] for n in effective])
    # A hand overlay keeps no source forearm: wrist-assist skin follows the current
    # wrist palm frame. The full-body probe retains its ancestor fallbacks.
    hand_effective = list(effective)
    for i, name in enumerate(source_names):
        if name.startswith('Wrist_Assist_'):
            hand_effective[i] = 'Wrist_' + name[-1]
    hand_matrices = np.asarray([matrices[n] for n in hand_effective])
    hand_sources = np.array([n.startswith('Finger_') or n.startswith('Wrist_') for n in source_names])
    primitives, shape_report = [], []
    source_weight_mass = np.zeros(len(source_names))
    hand_source_weight_mass = np.zeros(len(source_names))
    for mesh in source_doc['meshes']:
        for primitive in mesh['primitives']:
            if primitive.get('mode', 4) != 4:
                raise ValueError('Only triangle meshes supported')
            attrs = primitive['attributes']
            before = reference.accessor(attrs['POSITION']).astype(float)
            normals = reference.accessor(attrs['NORMAL']).astype(float)
            joints = reference.accessor(attrs['JOINTS_0']).astype(int)
            weights = reference.accessor(attrs['WEIGHTS_0']).astype(float)
            if np.any(weights < 0) or np.any(weights.sum(axis=1) <= 0):
                raise ValueError('Source has zero-weight vertices')
            weights /= weights.sum(axis=1, keepdims=True)
            points = np.column_stack((before, np.ones(len(before))))
            fitted_modes = {}
            for mode, transform_set, effective_names in [('body', all_matrices, effective), ('hands', hand_matrices, hand_effective)]:
                fitted = np.zeros_like(before)
                fitted_normals = np.zeros_like(normals)
                for column in range(4):
                    transforms = transform_set[joints[:, column]]
                    fitted += np.einsum('nij,nj->ni', transforms[:, :3], points) * weights[:, column, None]
                    normal_frames = np.linalg.inv(transforms[:, :3, :3]).transpose(0, 2, 1)
                    fitted_normals += np.einsum('nij,nj->ni', normal_frames, normals) * weights[:, column, None]
                fitted_normals /= np.maximum(np.linalg.norm(fitted_normals, axis=1, keepdims=True), 1e-12)
                target_joints = np.zeros_like(joints, dtype=np.uint16)
                target_weights = np.zeros_like(weights)
                for i in range(len(joints)):
                    combined = {}
                    for bone, weight in zip(joints[i], weights[i]):
                        if weight > 0:
                            target_id = target_ids[mapping[effective_names[bone]]]
                            combined[target_id] = combined.get(target_id, 0.) + weight
                    for col, (target_id, weight) in enumerate(sorted(combined.items(), key=lambda item: -item[1])):
                        target_joints[i, col], target_weights[i, col] = target_id, weight
                fitted_modes[mode] = {'position': fitted, 'normal': fitted_normals, 'joints': target_joints, 'weights': target_weights}
            fitted = fitted_modes['body']['position']
            triangles = reference.accessor(primitive['indices']).astype(np.uint32).reshape(-1, 3)
            hand_weight = (weights * hand_sources[joints]).sum(axis=1)
            hand_triangles = triangles[(hand_weight[triangles] >= .5).all(axis=1)]
            hand_vertices = np.unique(hand_triangles)
            np.add.at(source_weight_mass, joints.reshape(-1), weights.reshape(-1))
            np.add.at(hand_source_weight_mass, joints[hand_vertices].reshape(-1), weights[hand_vertices].reshape(-1))
            fallback_mass = float(sum(weights[:, col][np.array([source_names[b] not in mapping for b in joints[:, col]])].sum() for col in range(4)))
            shape_report.append({'source_mesh': mesh['name'], 'vertices': len(before), 'triangles': len(triangles),
                'hand_triangles': len(hand_triangles), 'fallback_weight_fraction': fallback_mass / len(before),
                'aabb_min': fitted.min(axis=0).tolist(), 'aabb_max': fitted.max(axis=0).tolist(),
                'quality': triangle_quality(before, fitted, triangles)})
            if not np.isfinite(fitted).all() or not np.isfinite(fitted_normals).all():
                raise ValueError('Nonfinite fitted mesh')
            if not np.allclose(target_weights.sum(axis=1), 1, atol=1e-7) or target_joints.max() >= len(target_bones):
                raise ValueError('Invalid transferred skin weights')
            primitives.append({'name': mesh['name'], **fitted_modes['body'], 'triangles': triangles, 'hand_triangles': hand_triangles,
                'hand_fit': fitted_modes['hands'],
                'material': primitive['material'], 'uv': reference.accessor(attrs['TEXCOORD_0']) if 'TEXCOORD_0' in attrs else None,
                'before': before})
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs = []
    for mode in ('hands', 'body'):
        writer = Gltf()
        doc = writer.document
        doc['asset']['generator'] = 'Frontier offline attributed anatomical mesh fitting probe'
        doc['materials'] = copy.deepcopy(source_doc['materials'])
        doc['textures'] = copy.deepcopy(source_doc.get('textures', []))
        doc['samplers'] = copy.deepcopy(source_doc.get('samplers', []))
        for image in source_doc.get('images', []):
            image = copy.deepcopy(image)
            image['bufferView'] = writer.view(reference.view(image['bufferView']))
            doc['images'].append(image)
        doc['nodes'].append({'name': 'Actor_B_reference_fit', 'children': []})
        doc['scenes'][0]['nodes'] = [0]
        for i, (bone, local) in enumerate(zip(target_bones, target_local)):
            doc['nodes'].append({'name': bone['name'], 'matrix': local.T.reshape(-1).tolist()})
            parent_node = 0 if bone['parent'] is None else target_ids[bone['parent']] + 1
            doc['nodes'][parent_node].setdefault('children', []).append(i + 1)
        doc['skins'].append({'name': 'Actor_B_canonical_null_add_291', 'joints': list(range(1, len(target_bones) + 1)),
            'skeleton': 0, 'inverseBindMatrices': writer.accessor(np.array([np.linalg.inv(w).T.reshape(-1) for w in target_world]), 'MAT4')})
        quality, counts, total_vertices, all_positions = [], [], 0, []
        crops = []
        for primitive in primitives:
            if mode == 'hands':
                if not len(primitive['hand_triangles']):
                    continue
                primitive = clip_hand_wrist({**primitive, **primitive['hand_fit'], 'triangles': primitive['hand_triangles']}, source_positions, mapping)
                crops.append({'source_mesh': primitive['name'], **primitive['wrist_crop']})
            triangles = primitive['triangles']
            if not len(triangles):
                continue
            vertices = np.unique(triangles)
            remap = np.full(len(primitive['position']), -1, dtype=int)
            remap[vertices] = np.arange(len(vertices))
            selected_triangles = remap[triangles]
            positions = primitive['position'][vertices]
            attrs = {'POSITION': writer.accessor(positions, 'VEC3', target=34962, bounds=True),
                'NORMAL': writer.accessor(primitive['normal'][vertices], 'VEC3', target=34962),
                'JOINTS_0': writer.accessor(primitive['joints'][vertices], 'VEC4', 5123, 34962),
                'WEIGHTS_0': writer.accessor(primitive['weights'][vertices], 'VEC4', target=34962)}
            if primitive['uv'] is not None:
                attrs['TEXCOORD_0'] = writer.accessor(primitive['uv'][vertices], 'VEC2', target=34962)
            mesh_id = len(doc['meshes'])
            doc['meshes'].append({'name': 'Reference_' + mode + '_' + primitive['name'],
                'primitives': [{'attributes': attrs, 'indices': writer.accessor(selected_triangles.reshape(-1), 'SCALAR', 5125, 34963),
                    'material': primitive['material'], 'mode': 4}], 'extras': {'source_mesh': primitive['name']}})
            node_id = len(doc['nodes'])
            doc['nodes'].append({'name': 'Reference_' + mode + '_' + primitive['name'], 'mesh': mesh_id, 'skin': 0})
            doc['nodes'][0]['children'].append(node_id)
            counts.append({'source_mesh': primitive['name'], 'vertices': len(vertices), 'triangles': len(triangles)})
            quality.append(triangle_quality(primitive['before'], primitive['position'], triangles))
            total_vertices += len(vertices)
            all_positions.extend(positions)
        if not counts:
            raise ValueError('No selected geometry for ' + mode)
        doc['extras'] = {'source_attribution': source_doc.get('extras', {}).get('source_attribution', []),
            'source_glb': str(source.resolve()), 'source_glb_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'target_bind_record': str(target_record), 'target_bind_record_sha256': hashlib.sha256(target_record.read_bytes()).hexdigest(),
            'semantic_map': str(semantic_map), 'fit_method': 'Weighted anatomical rest-frame transforms, mapped-ancestor weight fallback',
            'prototype_only': True, 'mode': mode, 'source_uv_v_flipped': source_doc.get('extras', {}).get('source_uv_v_flipped', False)}
        path = output_dir / ('link_' + mode + '_actor_b.glb')
        writer.save(path)
        check = Glb(path)
        if len(check.document['skins'][0]['joints']) != len(target_bones):
            raise ValueError('Output skin bone count changed')
        matrices_ = check.accessor(check.document['skins'][0]['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
        bind_error = float(np.max(np.abs(np.asarray(target_world) @ matrices_ - np.eye(4))))
        if bind_error > 1e-5:
            raise ValueError('Output inverse-bind identity mismatch')
        bbox = np.asarray(all_positions)
        outputs.append({'mode': mode, 'path': str(path.resolve()), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bones': len(target_bones), 'meshes': counts, 'vertices': total_vertices, 'triangles': sum(s['triangles'] for s in counts),
            'maximum_inverse_bind_error': bind_error, 'aabb_min': bbox.min(axis=0).tolist(), 'aabb_max': bbox.max(axis=0).tolist(),
            'triangle_quality': quality, 'wrist_crops': crops})
    face_center_source = (source_positions['Eyeball_L'] + source_positions['Eyeball_R']) * .5
    face_fit = (matrices['Head'] @ np.r_[face_center_source, 1.])[:3] - target_positions['headb']
    weighted_mapping_report = {}
    for mode, masses in [('hands', hand_source_weight_mass), ('body', source_weight_mass)]:
        active = masses > 1e-9
        fallback = np.array([n not in mapping for n in source_names])
        weighted_mapping_report[mode] = {'weighted_source_bones': int(active.sum()),
            'directly_mapped_weighted_source_bones': int((active & ~fallback).sum()),
            'ancestor_fallback_weighted_source_bones': int((active & fallback).sum()),
            'ancestor_fallback_weight_fraction': float(masses[fallback].sum() / masses.sum()),
            'fallbacks_with_actual_weight': [{'source': source_names[i], 'mapped_source_ancestor': effective[i],
                'target': mapping[effective[i]], 'vertex_weight_mass': float(masses[i])}
                for i in np.flatnonzero(active & fallback)]}
    weighted_mapping_report['hands']['measurement_scope'] = 'pre-crop source hand candidate triangles; wrist-assist hand weights use explicit wrist proxies, not forearm ancestor transforms'
    report = {'status': 'Isolated anatomical mesh fitting prototype; not a tested animation retarget or production character',
        'source_glb': str(source.resolve()), 'source_glb_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_attribution': source_doc.get('extras', {}).get('source_attribution', []),
        'target_bind_record': str(target_record), 'target_bind_record_sha256': hashlib.sha256(target_record.read_bytes()).hexdigest(),
        'semantic_map_sha256': hashlib.sha256(semantic_map.read_bytes()).hexdigest(),
        'target_bones': len(target_bones), 'source_bones': len(source_names), 'semantic_pairs': len(mapping),
        'maximum_anchor_error_m': max(x['anchor_error_m'] for x in landmark_report),
        'maximum_child_landmark_error_m': max(x['child_landmark_error_m'] or 0. for x in landmark_report),
        'fitted_face_forward_from_head_m': face_fit.tolist(), 'face_points_toward_positive_z': bool(face_fit[2] > 0),
        'landmarks': landmark_report, 'unmapped_source_weight_fallbacks': fallback_report,
        'hand_only_weight_overrides': [{'source': name, 'transform_source_landmark': hand_effective[i],
            'target': mapping[hand_effective[i]], 'reason': 'source lower-wrist assists are cropped; remaining hand skin follows current wrist'}
            for i, name in enumerate(source_names) if hand_effective[i] != effective[i]],
        'weighted_mapping_loss': weighted_mapping_report, 'source_shapes': shape_report, 'outputs': outputs,
        'limitations': ['Source shaders are not ported; portable source albedo/PBR is retained.',
            'Finger identities are anatomical candidates; palm/finger fitting needs rendered verification.',
            'Ancestor fallback removes unsupported face, hair, gear and helper motion.',
            'Full-body weighted transforms can warp silhouettes at joint transitions; triangle area statistics do not prove visual quality.',
            'Hand polygons are cropped at anatomical wrist planes; final seam welding and native body-region IDs are not authored.',
            'Existing creator morph targets, garment fitting and source animation transfer are not included.',
            'Only geometry present in the selected source GLB is available; no missing clothing is invented.']}
    (output_dir / 'fit_report.json').write_text(json.dumps(report, indent=2) + '\n')
    summary = {k: report[k] for k in ['status', 'target_bones', 'source_bones', 'semantic_pairs',
        'maximum_anchor_error_m', 'maximum_child_landmark_error_m', 'face_points_toward_positive_z']}
    summary['outputs'] = [{k: row[k] for k in ['mode', 'path', 'vertices', 'triangles', 'maximum_inverse_bind_error']}
        for row in outputs]
    summary['weighted_mapping_loss'] = {mode: {k: v for k, v in row.items() if k != 'fallbacks_with_actual_weight'}
        for mode, row in weighted_mapping_report.items()}
    print(json.dumps(summary, indent=2))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--target-bind', type=Path, default=Path('tools/character/rig/actor_b_skeleton.json'))
    parser.add_argument('--bone-map', type=Path, default=Path('data/retarget/botw_reference_bone_map.json'))
    parser.add_argument('--output-dir', type=Path, default=Path('artifacts/world_reference/character_fit'))
    args = parser.parse_args()
    fit(args.source, args.target_bind, args.bone_map, args.output_dir)
