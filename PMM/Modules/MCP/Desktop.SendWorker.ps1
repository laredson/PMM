param([Parameter(Mandatory=$true)][string]$DispatchPath,[switch]$VerifyOnly)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $PSScriptRoot 'MCP.Service.ps1')
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
$d=Read-PMMMCPJson $DispatchPath
if($DispatchPath -ine (Get-PMMDesktopFile ($d.caseId+'\dispatch.json'))){throw 'Invalid dispatch location.'}
$result=@{requestId=$d.requestId;status='ASSISTED';reason='Destination, workspace and composer could not all be verified.';utc=[DateTime]::UtcNow.ToString('o')}
try{
    Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
    Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class PMMDesktopWindow {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
"@
    $deadline=[DateTime]::UtcNow.AddSeconds(8)
    do {
        $hwnd=[PMMDesktopWindow]::GetForegroundWindow()
        $window=[Windows.Automation.AutomationElement]::FromHandle($hwnd)
        if(-not $window){break}
        $proc=Get-Process -Id $window.Current.ProcessId
        if(-not $d.packageRoot -or -not $proc.Path.StartsWith($d.packageRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){Start-Sleep -Milliseconds 500;continue}
        $elements=$window.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
        $composer=$null;$send=$null;$pathFound=$false;$ambiguous=$false
        foreach($element in $elements){
            if($element.Current.IsOffscreen){continue}
            $name=$element.Current.Name
            $selection=$null
            if($name -ceq $d.root -and $element.TryGetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern,[ref]$selection) -and $selection.Current.IsSelected){$pathFound=$true}
            $value=$null
            if($element.Current.ControlType -eq [Windows.Automation.ControlType]::Edit -and $element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$value) -and -not $value.Current.IsReadOnly -and $value.Current.Value -ceq $d.prompt){if($composer){$ambiguous=$true};$composer=$element}
            if($element.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $name -cin @('Send','Send message','Enviar','Enviar mensaje') -and $element.Current.IsEnabled){if($send){$ambiguous=$true};$send=$element}
            $wp=$null
            if($element.TryGetCurrentPattern([Windows.Automation.WindowPattern]::Pattern,[ref]$wp) -and $wp.Current.IsModal){$ambiguous=$true}
        }
        if($composer -and $send -and $pathFound -and -not $ambiguous){
            $invoke=$null
            if(-not $send.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern,[ref]$invoke)){break}
            $fresh=Get-PMMDesktopDispatch $d.caseId
            $case=Get-PMMMCPCase $d.caseId;$view=ConvertTo-PMMMCPCase $case
            if($fresh.phase -eq 'CANCELLED' -or -not(Get-PMMMCPEnabled) -or $fresh.requestId -cne $d.requestId -or -not $view.mcpRequest -or $view.mcpRequest.requestId -cne $d.requestId -or $view.aiReply){$result.reason='Request changed or already claimed.';break}
            if([PMMDesktopWindow]::GetForegroundWindow() -ne $hwnd){break}
            $currentValue=$composer.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
            if($currentValue.Current.Value -cne $d.prompt){break}
            $result.status='VERIFIED';$result.reason='Exact composer, root path, package and foreground window verified.'
            if(-not $VerifyOnly){$invoke.Invoke();$result.status='SENT'}
            break
        }
        Start-Sleep -Milliseconds 500
    }while([DateTime]::UtcNow -lt $deadline)
}catch{$result.reason='Desktop accessibility unavailable: '+$_.Exception.GetType().Name}
if($VerifyOnly){$result|ConvertTo-Json -Compress}else{Write-PMMAIIOJsonAtomic (Get-PMMDesktopFile ($d.caseId+'\send-result.json')) $result 5}
