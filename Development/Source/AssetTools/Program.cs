using UAssetAPI;
using UAssetAPI.UnrealTypes;
using UAssetAPI.Unversioned;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json;
using System.Reflection;
using System.Collections;
using System.Security.Cryptography;
static class Program {
 static int Main(string[] args) {
  try {
   if(args.Length==3 && args[0]=="schema") {
    var mapping=new Usmap(args[1]);
    foreach(DictionaryEntry entry in (IDictionary)mapping.Schemas) {
     if(!entry.Key.ToString()!.Contains(args[2],StringComparison.OrdinalIgnoreCase))continue;
     Console.WriteLine(JsonConvert.SerializeObject(entry.Value,new JsonSerializerSettings {ReferenceLoopHandling=ReferenceLoopHandling.Ignore,MaxDepth=12}));
    }
    return 0;
   }
   if(args.Length!=4)throw new ArgumentException("source.uasset mappings.usmap request.json output.uasset");
   var asset=new UAsset(args[0],EngineVersion.VER_UE5_1,new Usmap(args[1]));
   var doc=JObject.Parse(asset.SerializeJson());
   if(doc["Exports"]!.Any(x=>x["$type"]!.ToString().Contains("RawExport")))throw new InvalidDataException("UNPARSED_EXPORT: asset includes opaque data; structured edit refused.");
   var request=JObject.Parse(File.ReadAllText(args[2]));
   string pointer=request.Value<string>("path")??"";
   if(!pointer.StartsWith("/Exports/") || !pointer.EndsWith("/Value"))throw new InvalidDataException("Only an interpreted property Value may change.");
   JToken token=doc;
   foreach(var part in pointer.Split('/').Skip(1)){
    var key=part.Replace("~1","/").Replace("~0","~");
    token=token is JArray a ? a[int.Parse(key)] : token[key]??throw new InvalidDataException("Property path missing.");
   }
   var parent=(JObject)token.Parent!.Parent!;
   var type=parent.Value<string>("$type")??"";
   var allowed=new[]{"IntPropertyData","Int64PropertyData","FloatPropertyData","DoublePropertyData","BoolPropertyData"};
   if(!allowed.Any(t=>type.StartsWith("UAssetAPI.PropertyTypes.Objects."+t+",")))throw new InvalidDataException("Only int, int64, float, double and boolean properties are editable.");
   var expected=JToken.Parse(request.Value<string>("expected")!);
   var value=JToken.Parse(request.Value<string>("value")!);
   if(!JToken.DeepEquals(token,expected))throw new InvalidDataException("Expected property value does not match.");
   if(value.Type!=token.Type && !(token.Type==JTokenType.Float && value.Type==JTokenType.Integer))throw new InvalidDataException("Property type cannot change.");
   if(value.Type is not (JTokenType.Integer or JTokenType.Float or JTokenType.Boolean))throw new InvalidDataException("Scalar required.");
   if(JToken.DeepEquals(token,value))throw new InvalidDataException("No-op edit refused.");
   token.Replace(value);
   var edited=UAsset.DeserializeJson(doc.ToString(Formatting.None));edited.Mappings=asset.Mappings;
   Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(args[3]))!);
   edited.Write(args[3]);
   var check=new UAsset(args[3],EngineVersion.VER_UE5_1,asset.Mappings);
   var actual=JObject.Parse(check.SerializeJson());
   Normalize(doc);Normalize(actual);
   if(!JToken.DeepEquals(doc["Exports"],actual["Exports"]))throw new InvalidDataException("Serialized exports differ beyond requested edit.");
   if(!JToken.DeepEquals(doc["NameMap"],actual["NameMap"]) || !JToken.DeepEquals(doc["Imports"],actual["Imports"]))throw new InvalidDataException("Asset dependencies changed unexpectedly.");
   Console.WriteLine("{\"status\":\"VALIDATED_EDIT\",\"runtime\":\"UNPROVEN\"}");
   return 0;
  } catch(Exception ex){Console.Error.WriteLine(ex.Message);return 2;}
 }
 static void Normalize(JToken node){
  if(node is JObject obj){
   foreach(var key in new[]{"SerialOffset","SerialSize","ScriptSerializationStartOffset","ScriptSerializationEndOffset"})obj.Remove(key);
   foreach(var p in obj.Properties().ToArray())Normalize(p.Value);
  }else if(node is JArray a)foreach(var child in a)Normalize(child);
 }
}
