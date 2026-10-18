// Offline source-preserving BFRES mesh/skin dump; not game runtime code.
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Text.Json;
using System.Security.Cryptography;
using BfresLibrary;
using BfresLibrary.Helpers;
using Syroot.BinaryData;
using Syroot.Maths;

class BfresMeshExport
{
    static float[] V(Vector3F x) => new [] { x.X, x.Y, x.Z };
    static float[] V(Vector4F x) => new [] { x.X, x.Y, x.Z, x.W };
    static float[] M(Matrix3x4 x) => new [] { x.M11,x.M12,x.M13,x.M14,x.M21,x.M22,x.M23,x.M24,x.M31,x.M32,x.M33,x.M34 };
    static int Main(string[] args)
    {
        if (args.Length < 2) { Console.Error.WriteLine("Usage: BfresMeshExport input.bfres output.json [texture-output-directory]"); return 2; }
        var input = Path.GetFullPath(args[0]);
        var res = new ResFile(input);
        var models = new List<object>();
        foreach (var model in res.Models.Values)
        {
            var sk = model.Skeleton;
            var shapes = new List<object>();
            foreach (var shape in model.Shapes.Values)
            {
                var buffer = model.VertexBuffers[shape.VertexBufferIndex];
                var helper = new VertexBufferHelper(buffer, ByteOrder.BigEndian);
                var mesh = shape.Meshes[0]; // Preserve source LOD zero, do not duplicate lower LODs.
                shapes.Add(new {
                    name=shape.Name, bone=(int)shape.BoneIndex, material=(int)shape.MaterialIndex,
                    skin_count=(int)shape.VertexSkinCount, skin_bones=shape.SkinBoneIndices,
                    primitive=mesh.PrimitiveType.ToString(), first_vertex=mesh.FirstVertex,
                    indices=mesh.GetIndices().ToArray(),
                    attributes=helper.Attributes.ToDictionary(a=>a.Name,a=>a.Data.Select(x=>V(x)).ToArray())
                });
            }
            models.Add(new {
                name=model.Name, scaling=sk.FlagsScaling.ToString(), rotation=sk.FlagsRotation.ToString(),
                matrix_to_bone=sk.MatrixToBoneList,
                inverse_model_matrices=sk.InverseModelMatrices.Select(x=>M(x)).ToArray(),
                bones=sk.Bones.Values.Select(b=>new {
                    name=b.Name,parent=(int)b.ParentIndex,scale=V(b.Scale),rotation=V(b.Rotation),position=V(b.Position),
                    rotation_mode=b.FlagsRotation.ToString(),flags_transform=b.FlagsTransform.ToString(),
                    smooth_matrix=(int)b.SmoothMatrixIndex, rigid_matrix=(int)b.RigidMatrixIndex,
                    inverse_matrix=M(b.InverseMatrix)
                }).ToArray(),
                materials=model.Materials.Values.Select(m=>new {
                    name=m.Name, textures=m.TextureRefs.Select(t=>t.Name).ToArray(),
                    samplers=m.Samplers.Keys.ToArray(),
                    sampler_assigns=m.ShaderAssign.SamplerAssigns.Keys.ToDictionary(x=>x,x=>m.ShaderAssign.SamplerAssigns[x].String),
                    shader_archive=m.ShaderAssign.ShaderArchiveName, shader_model=m.ShaderAssign.ShadingModelName
                }).ToArray(), shapes=shapes
            });
        }
        var textures = new List<object>();
        if (args.Length > 2)
        {
            var dir=Path.GetFullPath(args[2]); Directory.CreateDirectory(dir);
            foreach(var texture in res.Textures.Values)
            {
                if (texture is not BfresLibrary.WiiU.Texture t) continue;
                var data=t.GetDeswizzledData(0,0);
                var name=Path.GetFileName(t.Name)+".raw";
                File.WriteAllBytes(Path.Combine(dir,name),data);
                textures.Add(new {name=t.Name,width=t.Width,height=t.Height,format=t.Format.ToString(),
                    file=name, bytes=data.Length, channels=new [] {t.CompSelR.ToString(),t.CompSelG.ToString(),t.CompSelB.ToString(),t.CompSelA.ToString()}});
            }
        }
        var output=new { source=input,source_sha256=Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(input))).ToLowerInvariant(),
            attribution="Extracted local The Legend of Zelda: Breath of the Wild reference asset; Nintendo source names retained. No ownership transfer claimed.",
            models=models,textures=textures };
        File.WriteAllText(args[1],JsonSerializer.Serialize(output,new JsonSerializerOptions {WriteIndented=true}));
        Console.WriteLine($"Exported {models.Count} models and {textures.Count} textures to {args[1]}");
        return 0;
    }
}
