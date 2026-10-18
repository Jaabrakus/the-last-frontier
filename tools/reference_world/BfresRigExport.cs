// Offline BFRES inspection, never a Godot runtime dependency.
using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text.Json;
using BfresLibrary;

class BfresRigExport
{
    static void Main(string[] args)
    {
        if (args.Length != 2) throw new ArgumentException("input.fres output.json");
        if (File.Exists(args[1])) throw new IOException("Refusing existing output");
        var res = new ResFile(args[0]);
        var models = res.Models.Values.Select(model => new {
            name = model.Name,
            shape_count = model.Shapes.Count,
            material_count = model.Materials.Count,
            scaling_mode = model.Skeleton.FlagsScaling.ToString(),
            rotation_mode = model.Skeleton.FlagsRotation.ToString(),
            matrix_to_bone = model.Skeleton.MatrixToBoneList,
            bones = model.Skeleton.Bones.Values.Select((bone, i) => new {
                index = i, name = bone.Name, parent = bone.ParentIndex,
                translation = new[] {bone.Position.X, bone.Position.Y, bone.Position.Z},
                rotation = new[] {bone.Rotation.X, bone.Rotation.Y, bone.Rotation.Z, bone.Rotation.W},
                rotation_mode = bone.FlagsRotation.ToString(),
                scale = new[] {bone.Scale.X, bone.Scale.Y, bone.Scale.Z},
                transform_flags = bone.FlagsTransform.ToString(),
                smooth_matrix_index = bone.SmoothMatrixIndex,
                rigid_matrix_index = bone.RigidMatrixIndex,
            }).ToArray()
        }).ToArray();
        var output = new {
            source = Path.GetFullPath(args[0]),
            source_sha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(args[0]))).ToLowerInvariant(),
            source_game = "The Legend of Zelda: Breath of the Wild (Wii U)",
            purpose = "Locally supplied source rig inspection; not newly authored game content",
            format = "BFRES", is_switch = res.IsPlatformSwitch, models
        };
        File.WriteAllText(args[1], JsonSerializer.Serialize(output, new JsonSerializerOptions {WriteIndented=true}));
        foreach (var model in models)
            Console.WriteLine($"{model.name}: {model.bones.Length} bones, {model.shape_count} shapes, {model.scaling_mode}");
    }
}
