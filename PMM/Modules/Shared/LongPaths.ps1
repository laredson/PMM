# Windows filesystem access independent of MAX_PATH and the host registry policy.
# Function definitions only; the small Win32 bridge loads on the calling worker.
function Initialize-PMMNativePaths {
  if('PMM.NativePaths' -as [type]){return}
  Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.ComponentModel;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace PMM {
 public sealed class PathEntry { public string FullName; public string Name; public long Length; public DateTime LastWriteTimeUtc; public bool Directory; public uint Attributes; }
 public static class NativePaths {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct FindData {
   public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Creation,Access,Write;
   public uint SizeHigh,SizeLow,Reserved0,Reserved1;
   [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string Name;
   [MarshalAs(UnmanagedType.ByValTStr,SizeConst=14)] public string Alternate;
  }
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFullPathName(string path,uint size,System.Text.StringBuilder result,IntPtr part);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFileAttributes(string path);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateDirectory(string path,IntPtr security);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string path,uint access,uint share,IntPtr security,uint disposition,uint flags,IntPtr template);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr FindFirstFile(string path,out FindData data);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool FindNextFile(IntPtr handle,out FindData data);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool FindClose(IntPtr handle);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool DeleteFile(string path);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool RemoveDirectory(string path);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool MoveFileEx(string from,string to,uint flags);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CopyFile(string from,string to,bool failIfExists);
  static Exception Error(string action,string path) { return new IOException(action+": "+path,new Win32Exception(Marshal.GetLastWin32Error())); }
  public static string Full(string path) {
   if(String.IsNullOrWhiteSpace(path))throw new ArgumentException("Empty filesystem path.");
   if(path.StartsWith(@"\\?\UNC\",StringComparison.OrdinalIgnoreCase))path=@"\\"+path.Substring(8);
   else if(path.StartsWith(@"\\?\"))path=path.Substring(4);
   var b=new System.Text.StringBuilder(32768);uint n=GetFullPathName(path,(uint)b.Capacity,b,IntPtr.Zero);
   if(n==0||n>=b.Capacity)throw Error("Cannot resolve path",path);string full=b.ToString();return full.Length==3 && full[1]==':' ? full : full.TrimEnd('\\');
  }
  static string Extended(string path) { string p=Full(path);return p.StartsWith(@"\\")?@"\\?\UNC\"+p.Substring(2):@"\\?\"+p; }
  public static bool Exists(string path,bool directory) { uint a=GetFileAttributes(Extended(path));if(a==0xffffffff){int e=Marshal.GetLastWin32Error();if(e==2||e==3)return false;throw Error("Cannot inspect path",path);}return ((a&16)!=0)==directory; }
  public static void EnsureDirectory(string path) {
   string p=Full(path);if(Exists(p,true))return;
   int i=p.LastIndexOf('\\');if(i>2)EnsureDirectory(p.Substring(0,i));
   if(!CreateDirectory(Extended(p),IntPtr.Zero)&&!Exists(p,true))throw Error("Cannot create directory",p);
  }
  public static FileStream Open(string path,bool write) {
   string p=Full(path);if(write)EnsureDirectory(p.Substring(0,p.LastIndexOf('\\')));
   var h=CreateFile(Extended(p),write?0x40000000u:0x80000000u,write?0u:1u,IntPtr.Zero,write?2u:3u,0x80,IntPtr.Zero);
   if(h.IsInvalid){var error=Error(write?"Cannot write file":"Cannot read file",p);h.Dispose();throw error;}
   try{return new FileStream(h,write?FileAccess.Write:FileAccess.Read);}catch{h.Dispose();throw;}
  }
  public static PathEntry[] Entries(string path,bool recursive) {
   var result=new List<PathEntry>();Enumerate(Full(path),recursive,result);return result.ToArray();
  }
  static void Enumerate(string path,bool recursive,List<PathEntry> result) {
   FindData d;IntPtr h=FindFirstFile(Extended(path)+@"\*",out d);
   if(h==new IntPtr(-1)){int e=Marshal.GetLastWin32Error();if(e==2&&Exists(path,true))return;throw Error("Cannot enumerate directory",path);}
   try{do{if(d.Name=="."||d.Name=="..")continue;
    var row=new PathEntry{FullName=path+@"\"+d.Name,Name=d.Name,Length=((long)d.SizeHigh<<32)|d.SizeLow,Directory=(d.Attributes&16)!=0,Attributes=d.Attributes,LastWriteTimeUtc=DateTime.FromFileTimeUtc(((long)d.Write.dwHighDateTime<<32)|(uint)d.Write.dwLowDateTime)};
    result.Add(row);if(recursive&&row.Directory){if((d.Attributes&1024)!=0)throw new IOException("Reference directory cannot contain a reparse point: "+row.FullName);Enumerate(row.FullName,true,result);}
   }while(FindNextFile(h,out d));if(Marshal.GetLastWin32Error()!=18)throw Error("Directory enumeration failed",path);
   }finally{FindClose(h);}
  }
  public static void Delete(string path) { if(!DeleteFile(Extended(path))&&Exists(path,false))throw Error("Cannot delete file",path); }
  public static void Move(string from,string to) { if(!MoveFileEx(Extended(from),Extended(to),8))throw Error("Cannot move path",from); }
  public static void Copy(string from,string to) { string p=Full(to);EnsureDirectory(p.Substring(0,p.LastIndexOf('\\')));if(!CopyFile(Extended(from),Extended(p),false))throw Error("Cannot copy file",from); }
  public static void RemoveTree(string path,string allowedRoot) {
   string p=Full(path),r=Full(allowedRoot)+@"\";if(!p.StartsWith(r,StringComparison.OrdinalIgnoreCase))throw new IOException("Cleanup must remain inside its explicit root.");
   if(!Exists(p,true))return;
   uint a=GetFileAttributes(Extended(p));if((a&1024)!=0)throw new IOException("Refusing recursive reparse-point cleanup.");
   foreach(var e in Entries(p,false)){if(e.Directory)RemoveTree(e.FullName,allowedRoot);else Delete(e.FullName);}
   if(!RemoveDirectory(Extended(p)))throw Error("Cannot remove directory",p);
  }
 }
}
"@
}
function Get-PMMFullPath([string]$Path){Initialize-PMMNativePaths;return [PMM.NativePaths]::Full($Path)}
function Test-PMMFile([string]$Path){if(-not$Path){return $false};Initialize-PMMNativePaths;return [PMM.NativePaths]::Exists($Path,$false)}
function Test-PMMDirectory([string]$Path){if(-not$Path){return $false};Initialize-PMMNativePaths;return [PMM.NativePaths]::Exists($Path,$true)}
function New-PMMDirectory([string]$Path){Initialize-PMMNativePaths;[PMM.NativePaths]::EnsureDirectory($Path)}
function Get-PMMFiles([string]$Path,[switch]$Recurse){Initialize-PMMNativePaths;return @([PMM.NativePaths]::Entries($Path,[bool]$Recurse)|Where-Object{-not$_.Directory})}
function Open-PMMFile([string]$Path,[switch]$Write){Initialize-PMMNativePaths;return [PMM.NativePaths]::Open($Path,[bool]$Write)}
function Copy-PMMFile([string]$Source,[string]$Destination){Initialize-PMMNativePaths;[PMM.NativePaths]::Copy($Source,$Destination)}
function Remove-PMMFile([string]$Path){Initialize-PMMNativePaths;[PMM.NativePaths]::Delete($Path)}
function Move-PMMDirectory([string]$Source,[string]$Destination){Initialize-PMMNativePaths;[PMM.NativePaths]::Move($Source,$Destination)}
function Remove-PMMDirectory([string]$Path,[string]$Root){Initialize-PMMNativePaths;[PMM.NativePaths]::RemoveTree($Path,$Root)}
