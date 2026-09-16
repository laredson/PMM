using UAssetAPI;
using UAssetAPI.ExportTypes;
using UAssetAPI.UnrealTypes;
using UAssetAPI.Unversioned;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

// A bounded recipe primitive: rebuild the proven unlock list on the current game CDO.
// All other properties and Blueprint functions must survive readback unchanged.
internal static class AuatUpgrade {
 internal static int Run(string[] a) {
  if(a.Length!=7)throw new ArgumentException("auat-upgrade current.uasset current.usmap donor.uasset donor.usmap table.uasset output.uasset");
  var current=new UAsset(a[1],EngineVersion.VER_UE5_1,new Usmap(a[2]));
  var donor=new UAsset(a[3],EngineVersion.VER_UE5_1,new Usmap(a[4]));
  var table=new UAsset(a[5],EngineVersion.VER_UE5_1,current.Mappings);
  foreach(var asset in new[]{current,donor,table})
   if(asset.Exports.Any(x=>x is RawExport))throw new InvalidDataException("Opaque data: correct mappings and full semantic decoding are required.");
  var doc=JObject.Parse(current.SerializeJson());
  var old=JObject.Parse(donor.SerializeJson());
  var desired=Unlocks(old);
  var original=Unlocks(doc);
  var rows=table.Exports.OfType<DataTableExport>().Single().Table.Data.Select(r=>r.Name.ToString()).ToArray();
  var keys=desired.Select(Key).ToArray();
  if(keys.Length<100 || keys.Length>4096 || keys.Distinct(StringComparer.Ordinal).Count()!=keys.Length)throw new InvalidDataException("Unexpected donor unlock list.");
  if(!new HashSet<string>(rows,StringComparer.Ordinal).SetEquals(keys))throw new InvalidDataException("Donor technology IDs differ from the current table. Recipe needs review; no technology is silently dropped or invented.");
  // First prove that the serializer can preserve this exact current family.
  if(!current.VerifyBinaryEquality())throw new InvalidDataException("Current family cannot be losslessly round-tripped by this reader.");
  var names=(JArray)doc["NameMap"]!;
  foreach(var id in keys){
   // Let FName resolve numeric suffixes correctly and append needed base names.
   _=FName.FromString(current,id);
  }
  doc["NameMap"]=JObject.Parse(current.SerializeJson())["NameMap"]!.DeepClone();
  original.Replace(desired.DeepClone());
  var expected=(JObject)doc.DeepClone();
  var output=UAsset.DeserializeJson(doc.ToString(Formatting.None));
  output.Mappings=current.Mappings;
  Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(a[6]))!);
  output.Write(a[6]);
  var check=new UAsset(a[6],EngineVersion.VER_UE5_1,current.Mappings);
  if(check.Exports.Any(x=>x is RawExport))throw new InvalidDataException("Written output became opaque.");
  var actual=JObject.Parse(check.SerializeJson());
  Normalize(expected);Normalize(actual);
  foreach(var field in new[]{"Exports","Imports","NameMap"})
   if(!JToken.DeepEquals(expected[field],actual[field]))throw new InvalidDataException("Readback differs from the requested unlock-list edit: "+field);
  if(!check.VerifyBinaryEquality())throw new InvalidDataException("Output cannot be losslessly re-read.");
  Console.WriteLine(JsonConvert.SerializeObject(new {status="STRUCTURAL_PASS",runtime="UNPROVEN",technologies=keys.Length,changedProperty="DefaultUnlockTechnology",currentPropertiesPreserved=true,blueprintFunctionsPreserved=true}));
  return 0;
 }
 static JArray Unlocks(JObject doc) {
  var cdo=doc["Exports"]!.Single(x=>x.Value<string>("ObjectName")=="Default__BP_PalGameSetting_C");
  var prop=cdo["Data"]!.Single(x=>x.Value<string>("Name")=="DefaultUnlockTechnology");
  if(prop.Value<string>("ArrayType")!="StructProperty")throw new InvalidDataException("Unexpected unlock array type.");
  var values=(JArray)prop["Value"]!;
  foreach(var v in values)_=Key(v);
  return values;
 }
 static string Key(JToken entry) {
  if(entry.Value<string>("StructType")!="PalDataTableRowName_RecipeTechnologyData" || entry["Value"] is not JArray values || values.Count!=1 || values[0].Value<string>("Name")!="Key" || !values[0].Value<string>("$type")!.Contains("NamePropertyData"))throw new InvalidDataException("Unexpected technology reference structure.");
  return values[0].Value<string>("Value") ?? throw new InvalidDataException("Missing technology ID.");
 }
 static void Normalize(JToken node) {
  if(node is JObject obj){
   foreach(var key in new[]{"SerialOffset","SerialSize","ScriptSerializationStartOffset","ScriptSerializationEndOffset"})obj.Remove(key);
   foreach(var p in obj.Properties().ToArray())Normalize(p.Value);
  } else if(node is JArray arr)foreach(var child in arr)Normalize(child);
 }
}
