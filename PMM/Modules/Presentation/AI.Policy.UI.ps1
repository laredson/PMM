function Show-PMMAIPolicyDialog {
  $v=New-PMMThemedDialog (L 'AI level and account' 'Nivel de IA y cuenta')
  $policy=Get-PMMAIPolicy
  $note=[Windows.Controls.TextBlock]::new();$note.TextWrapping='Wrap';$note.Margin=[Windows.Thickness]::new(4)
  $note.Text=L 'Routine work uses Luna / low / standard speed. A harder stage needs a recorded reason and must fit this ceiling. Model access and account limits are refreshed before every request.' 'Las consultas sencillas usan Luna / ligero / velocidad estandar. Subir de nivel requiere un motivo registrado y respetar este limite. Se consultan los modelos disponibles y los limites de la cuenta antes de cada peticion.'
  [void]$v.body.Children.Add($note)
  $controls=@{}
  foreach($definition in @(
    @('Profile',(L 'Account profile' 'Perfil de cuenta'),@(
      @('Auto','Detect account','Detectar cuenta'),@('Free','Free / conservative','Gratuita / conservadora'),@('Paid','Paid account','Cuenta de pago'),@('ManualChat','Manual ChatGPT chat','Chat manual de ChatGPT'))),
    @('MaxStage',(L 'Allow reasoning up to' 'Permitir razonamiento hasta'),@(
      @('Routine','Routine only','Solo consultas sencillas'),@('Repair','Repair diagnosis','Diagnostico de reparaciones'),@('Complex','Complex repair design','Diseno de reparaciones complejas')))
  )){
    $label=[Windows.Controls.TextBlock]::new();$label.Text=$definition[1];[void]$v.body.Children.Add($label)
    $box=[Windows.Controls.ComboBox]::new();$box.Margin=[Windows.Thickness]::new(3);$box.DisplayMemberPath='Label';$box.SelectedValuePath='Value'
    $box.ItemsSource=@(foreach($item in $definition[2]){[pscustomobject]@{Value=$item[0];Label=(L $item[1] $item[2])}})
    $box.SelectedValue=$policy.($definition[0]);$controls[$definition[0]]=$box;[void]$v.body.Children.Add($box)
  }
  foreach($stage in @('Routine','Repair','Complex')){
    $row=[Windows.Controls.WrapPanel]::new()
    $label=[Windows.Controls.TextBlock]::new();$label.Text=L ($stage+': ') $(switch($stage){Routine{'Sencilla: '};Repair{'Reparacion: '};Complex{'Compleja: '}});$label.Width=95
    $model=[Windows.Controls.TextBox]::new();$model.Text=$policy.($stage+'Model');$model.Width=170;$model.Margin=[Windows.Thickness]::new(3)
    $effort=[Windows.Controls.ComboBox]::new();$effort.ItemsSource=@('low','medium','high','xhigh','max');$effort.SelectedItem=$policy.($stage+'Effort');$effort.Width=95;$effort.Margin=[Windows.Thickness]::new(3)
    [void]$row.Children.Add($label);[void]$row.Children.Add($model);[void]$row.Children.Add($effort);[void]$v.body.Children.Add($row)
    $controls[$stage+'Model']=$model;$controls[$stage+'Effort']=$effort
  }
  $api=[Windows.Controls.CheckBox]::new();$api.IsChecked=$policy.AllowApiBilling;$api.Content=L 'Allow separately billed API requests' 'Permitir peticiones API facturadas por separado';$api.Margin=[Windows.Thickness]::new(4);[void]$v.body.Children.Add($api)
  $status=[Windows.Controls.TextBlock]::new();$status.TextWrapping='Wrap';$status.Margin=[Windows.Thickness]::new(4)
  $capPath=Join-PMMPath 'State' 'ai-capabilities.json'
  if(Test-Path -LiteralPath $capPath){
    $cap=Read-PMMJsonFile $capPath;$status.Text=(L 'Last account check: ' 'Ultima comprobacion: ')+$cap.Plan+'; '+$cap.Utc+'. '+($cap.Models.model -join ', ')
  }else{$status.Text=L 'Account not checked yet. Manual chat delivery and its chosen model are not controlled by PMM; chat is not guaranteed to have zero usage.' 'Cuenta aun sin comprobar. PMM no controla la entrega ni el modelo elegido en el chat manual; no se garantiza consumo cero.'}
  [void]$v.body.Children.Add($status)
  $refresh=[Windows.Controls.Button]::new();$refresh.Content=L 'Check plan and models' 'Comprobar plan y modelos';$refresh.Margin=[Windows.Thickness]::new(3)
  $refresh.Tag=$status
  $refresh.Add_Click({param($sender,$eventArgs)
    $status=$sender.Tag
    try{
      Start-PMMDeepUIOperation DeepSource @{Action='RefreshAI'} {param($r)$Script:DeepControls.Status.Text=$r.ResultText}
      $status.Text=L 'Checking account metadata; the result appears in the analysis panel. Reopen these settings to see the new catalog.' 'Consultando la cuenta; el resultado aparecera en el panel de analisis. Reabre estos ajustes para ver el nuevo catalogo.'
    }catch{$status.Text=$_.Exception.Message}
  })
  $save=[Windows.Controls.Button]::new();$save.Content=L 'Save policy' 'Guardar politica';$save.Margin=[Windows.Thickness]::new(3)
  $save.Tag=@{Policy=$policy;Controls=$controls;Api=$api;Status=$status;Window=$v.window}
  $save.Add_Click({param($sender,$eventArgs)
    $state=$sender.Tag;$policy=$state.Policy;$controls=$state.Controls
    try{
      $policy.Profile=[string]$controls.Profile.SelectedValue;$policy.MaxStage=[string]$controls.MaxStage.SelectedValue;$policy.AllowApiBilling=[bool]$state.Api.IsChecked
      foreach($stage in @('Routine','Repair','Complex')){$policy.($stage+'Model')=$controls[$stage+'Model'].Text.Trim();$policy.($stage+'Effort')=[string]$controls[$stage+'Effort'].SelectedItem}
      Save-PMMAIPolicy $policy;$state.Window.Close()
    }catch{$state.Status.Text=$_.Exception.Message}
  })
  [void]$v.actions.Children.Add($refresh);[void]$v.actions.Children.Add($save)
  [void]$v.window.ShowDialog()
}
