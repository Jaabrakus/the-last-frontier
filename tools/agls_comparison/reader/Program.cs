using UAssetAPI;
using UAssetAPI.UnrealTypes;
using UAssetAPI.ExportTypes;
using System.Text.Json;
if(args[0]=="inventory") {
 using var output=new StreamWriter(args[2]);
 int n=0, errors=0;
 foreach(var path in Directory.EnumerateFiles(args[1],"*.uasset",SearchOption.AllDirectories).Order()) {
  try {
   var a=new UAsset(path,EngineVersion.UNKNOWN,customSerializationFlags:CustomSerializationFlags.SkipLoadingExports|CustomSerializationFlags.SkipPreloadDependencyLoading);
   output.WriteLine(JsonSerializer.Serialize(new {path=Path.GetRelativePath(args[1],path),records=a.AssetRegistryRecords?.Select(r=>new {r.Path,r.ClassName,r.TagMap}),imports=a.Imports.Select(i=>new {name=i.ObjectName.ToString(),type=i.ClassName.ToString()}),exports=a.Exports.Select(e=>new {name=e.ObjectName.ToString(),type=e.GetClassTypeForAncestry(a,out _).ToString()})}));
  } catch(Exception e) {errors++; output.WriteLine(JsonSerializer.Serialize(new {path=Path.GetRelativePath(args[1],path),error=e.Message}));}
  if(++n%500==0){output.Flush();Console.WriteLine($"Scanned {n}; errors {errors}");}
 }
 Console.WriteLine($"Done {n}; errors {errors}");
} else {
 var a=new UAsset(args[1],EngineVersion.UNKNOWN,customSerializationFlags:CustomSerializationFlags.SkipPreloadDependencyLoading);
 File.WriteAllText(args[2],a.SerializeJson(true));
 Console.WriteLine(JsonSerializer.Serialize(new {exports=a.Exports.Count,raw=a.Exports.Count(e=>e is RawExport),types=a.Exports.GroupBy(e=>e.GetType().Name).ToDictionary(g=>g.Key,g=>g.Count())}));
}
