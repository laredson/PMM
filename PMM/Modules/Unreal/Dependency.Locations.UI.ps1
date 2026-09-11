function Show-PMMDependencyLocation([string]$Component) {
    $v=New-PMMThemedDialog (L 'Locate installed tool or offline package' 'Localizar herramienta instalada o paquete offline')
    $hint=[Windows.Controls.TextBlock]::new();$hint.TextWrapping='Wrap';$hint.Margin=[Windows.Thickness]::new(0,0,0,12)
    $hint.Text=L 'Choose the installation folder or a file inside it. For Wwise, an offline download can also be selected; PMM will distinguish it from the installed SDK. Saving a path does not run the selected file.' 'Selecciona la carpeta de instalacion o un archivo dentro de ella. Para Wwise tambien puedes elegir el paquete offline; PMM lo distinguira del SDK instalado. Guardar una ruta no ejecuta el archivo seleccionado.'
    [void]$v.body.Children.Add($hint)
    $path=[Windows.Controls.TextBox]::new();$path.MinHeight=32;[void]$v.body.Children.Add($path)
    $pickers=[Windows.Controls.WrapPanel]::new();[void]$v.body.Children.Add($pickers)
    $errorLabel=[Windows.Controls.TextBlock]::new();$errorLabel.TextWrapping='Wrap';$errorLabel.Margin=[Windows.Thickness]::new(0,12,0,0);[void]$v.body.Children.Add($errorLabel)
    $state=@{window=$v.window;path=$path;error=$errorLabel;component=$Component;result=$null}
    foreach($kind in @('folder','file')){
        $b=[Windows.Controls.Button]::new();$b.Tag=$kind;$b.Margin=[Windows.Thickness]::new(0,8,8,0)
        $b.Content=if($kind -eq 'folder'){L 'Choose folder...' 'Elegir carpeta...'}else{L 'Choose file / executable...' 'Elegir archivo / ejecutable...'}
        $b.Add_Click({param($sender,$args)
            if($sender.Tag -eq 'folder'){
                $d=[Windows.Forms.FolderBrowserDialog]::new();try{if($d.ShowDialog() -eq 'OK'){$state.path.Text=$d.SelectedPath}}finally{$d.Dispose()}
            }else{
                $d=[Microsoft.Win32.OpenFileDialog]::new();$d.Filter='Tool files|*.exe;*.h;*.uplugin;*.xz;*.json|All files|*.*'
                if($d.ShowDialog($state.window)){$state.path.Text=$d.FileName}
            }
        }.GetNewClosure());[void]$pickers.Children.Add($b)
    }
    $cancel=[Windows.Controls.Button]::new();$cancel.Content=L 'Cancel' 'Cancelar';$cancel.IsCancel=$true;$cancel.MinWidth=100
    $cancel.Add_Click({$state.window.Close()}.GetNewClosure());[void]$v.actions.Children.Add($cancel)
    $save=[Windows.Controls.Button]::new();$save.Content=L 'Validate and save' 'Validar y guardar';$save.Margin=[Windows.Thickness]::new(8,0,0,0);$save.IsDefault=$true
    $save.Add_Click({try{$state.result=Set-PMMDependencyLocation $state.component $state.path.Text.Trim();$state.window.Close()}catch{$state.error.Text=$_.Exception.Message}}.GetNewClosure())
    [void]$v.actions.Children.Add($save);[void]$v.window.ShowDialog();return $state.result
}
