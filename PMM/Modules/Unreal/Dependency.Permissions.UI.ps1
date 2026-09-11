function Update-PMMDependencyPolicyLabel {
    if(-not(Get-Variable PMMDependencyPolicyLabel -Scope Script -ErrorAction SilentlyContinue)){return}
    $Script:PMMDependencyPolicyLabel.Text=if((Get-PMMDependencyPolicy).mode -eq 'automatic'){L 'Automatic installation authorized' 'Instalacion automatica autorizada'}else{L 'Ask before each installation' 'Preguntar en cada instalacion'}
}
function Show-PMMDependencyPermissions {
    $v=New-PMMThemedDialog (L 'Installation permissions' 'Permisos de instalacion')
    $mode=(Get-PMMDependencyPolicy).mode
    $note=[Windows.Controls.TextBlock]::new();$note.TextWrapping='Wrap'
    $note.Text=L 'This changes permission for future PMM catalog requests. It does not start an installation. Cancel jobs separately; an official installer already running may finish.' 'Cambia el permiso para futuras solicitudes del catalogo PMM. No inicia instalaciones. Los trabajos se cancelan por separado; un instalador oficial en marcha puede terminar.'
    [void]$v.body.Children.Add($note)
    $ask=[Windows.Controls.RadioButton]::new();$ask.Name='Ask';$ask.GroupName='Policy';$ask.Content=L 'Ask before each installation' 'Preguntar en cada instalacion';$ask.IsChecked=$mode -eq 'ask';$ask.Margin=[Windows.Thickness]::new(0,16,0,8)
    $automatic=[Windows.Controls.RadioButton]::new();$automatic.Name='Automatic';$automatic.GroupName='Policy';$automatic.Content=L 'Authorize automatic catalog installations' 'Autorizar instalaciones automaticas del catalogo';$automatic.IsChecked=$mode -eq 'automatic'
    [void]$v.body.Children.Add($ask);[void]$v.body.Children.Add($automatic)
    $state=@{accepted=$false;window=$v.window}
    $cancel=[Windows.Controls.Button]::new();$cancel.Content=L 'Cancel' 'Cancelar';$cancel.IsCancel=$true;$cancel.MinWidth=100
    $cancel.Add_Click({$state.window.Close()}.GetNewClosure())
    $accept=[Windows.Controls.Button]::new();$accept.Name='Accept';$accept.Content=L 'Accept' 'Aceptar';$accept.MinWidth=100;$accept.Margin=[Windows.Thickness]::new(8,0,0,0)
    $accept.Add_Click({$state.accepted=$true;$state.window.Close()}.GetNewClosure())
    [void]$v.actions.Children.Add($cancel);[void]$v.actions.Children.Add($accept)
    $Script:PMMDependencyModal=$true
    try{[void]$v.window.ShowDialog();if($state.accepted){Set-PMMDependencyPolicy $(if($automatic.IsChecked){'automatic'}else{'ask'})}}
    finally{$Script:PMMDependencyModal=$false;Update-PMMDependencyPolicyLabel}
}
