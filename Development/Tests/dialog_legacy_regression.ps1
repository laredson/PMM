
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
. ./PMM/Modules/Shared/Dialogs.ps1
$Window=[Windows.Window]::new()
foreach($pair in @(@('AppBackground','#081725'),@('PrimaryText','#FFFFFF'),@('CardBackground','#102638'),@('CardBorder','#3474A4'))){$Window.Resources[$pair[0]]=[Windows.Media.BrushConverter]::new().ConvertFromString($pair[1])}
$form=[Windows.Forms.Form]::new();$button=[Windows.Forms.Button]::new();$button.DialogResult='OK';$form.Controls.Add($button);$form.AcceptButton=$button
$form.Add_Shown({
 if($form.BackColor.R -ne 8 -or $button.FlatStyle -ne 'Flat'){throw 'Legacy form theme missing'}
 $form.DialogResult='OK';$form.Close()
})
$r=Show-PMMStyledDialog $form
if($r -ne 'OK'){throw 'Dialog result changed'}
$form.Dispose();$Window.Close()
'LEGACY_DIALOG_STYLE_RETURN_PASS'
