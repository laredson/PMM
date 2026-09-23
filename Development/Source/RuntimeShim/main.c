typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef u16 W;
typedef void* P;
typedef P H;

typedef struct { H hProcess; H hThread; u32 dwProcessId; u32 dwThreadId; } PI;
typedef struct {
    u32 cb; W* lpReserved; W* lpDesktop; W* lpTitle;
    u32 dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
    u16 wShowWindow, cbReserved2; u8* lpReserved2;
    H hStdInput, hStdOutput, hStdError;
} SI;

__declspec(dllimport) u32 __stdcall GetModuleFileNameW(H,W*,u32);
__declspec(dllimport) W* __stdcall GetCommandLineW(void);
__declspec(dllimport) int __stdcall CreateProcessW(const W*,W*,P,P,int,u32,P,const W*,SI*,PI*);
__declspec(dllimport) u32 __stdcall WaitForSingleObject(H,u32);
__declspec(dllimport) int __stdcall GetExitCodeProcess(H,u32*);
__declspec(dllimport) void __stdcall ExitProcess(u32);
__declspec(dllimport) int __stdcall CloseHandle(H);
__declspec(dllimport) H __stdcall GetStdHandle(u32);

static W exe_path[32768];
static W legacy_path[32768];
static W dir_path[32768];
static W child_cmd[65536];
static SI si;
static PI pi;

static void add_ascii(W* d, u32* at, const char* s) { while(*s) d[(*at)++]=(u8)*s++; }
static const W* after_exe(const W* cmd) {
    const W* p=cmd;
    while(*p==' '||*p=='\t')p++;
    if(*p=='"') { p++; while(*p&&*p!='"')p++; if(*p)p++; }
    else { while(*p&&*p!=' '&&*p!='\t')p++; }
    while(*p==' '||*p=='\t')p++;
    return p;
}
static int first_is_start(const W* p, const W** tail) {
    const W* s=p; int quoted=0;
    if(*s=='"'){quoted=1;s++;}
    const char* x="start"; u32 i=0;
    while(x[i]) { u16 c=s[i]; if(c>='A'&&c<='Z')c+=32; if(c!=(u8)x[i]) return 0; i++; }
    s+=i;
    if(quoted){if(*s!='"')return 0;s++;} else if(*s && *s!=' '&&*s!='\t')return 0;
    while(*s==' '||*s=='\t')s++;
    *tail=s; return 1;
}

void entry(void) {
    u32 n=GetModuleFileNameW(0,exe_path,32768); if(!n) ExitProcess(127);
    u32 cut=n; while(cut && exe_path[cut-1]!='\\' && exe_path[cut-1]!='/')cut--;
    if(!cut) ExitProcess(127);
    for(u32 i=0;i+1<cut;i++) dir_path[i]=exe_path[i];
    dir_path[cut-1]=0;
    for(u32 i=0;i<cut;i++) legacy_path[i]=exe_path[i];
    u32 at=cut; add_ascii(legacy_path,&at,"PMMRuntimeLegacy.exe"); legacy_path[at]=0;

    at=0; child_cmd[at++]='"'; for(u32 i=0;legacy_path[i];i++) child_cmd[at++]=legacy_path[i]; child_cmd[at++]='"';
    const W* rest=after_exe(GetCommandLineW()); const W* tail=0;
    if(*rest) {
        child_cmd[at++]=' ';
        if(first_is_start(rest,&tail)) {
            add_ascii(child_cmd,&at,"ui");
            if(*tail){child_cmd[at++]=' '; while(*tail)child_cmd[at++]=*tail++;}
        } else while(*rest) child_cmd[at++]=*rest++;
    }
    child_cmd[at]=0;

    si.cb=(u32)sizeof(SI);
    si.dwFlags=0x00000100;
    si.hStdInput=GetStdHandle((u32)-10);
    si.hStdOutput=GetStdHandle((u32)-11);
    si.hStdError=GetStdHandle((u32)-12);
    if(!CreateProcessW(legacy_path,child_cmd,0,0,1,0x08000000,0,dir_path,&si,&pi)) ExitProcess(127);
    WaitForSingleObject(pi.hProcess,0xffffffffu);
    u32 code=126; GetExitCodeProcess(pi.hProcess,&code);
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess); ExitProcess(code);
}
