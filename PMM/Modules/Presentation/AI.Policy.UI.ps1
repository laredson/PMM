function Update-PMMPolicyEfforts($ModelBox) {
  $state=$ModelBox.Tag
  if($state.Updating){return}
  $effort=$state.Effort
  $previous=[string]$effort.SelectedItem
  $entry=$ModelBox.SelectedItem
  $effort.ItemsSource=@()
  if($entry -and $entry.Available){
    $values=@($entry.Efforts)
    $effort.ItemsSource=$values
    if($previous -in $values){$effort.SelectedItem=$previous}else{$effort.SelectedIndex=-1}
    $effort.IsEnabled=$true
  }else{$effort.IsEnabled=$false}
}
function Update-PMMPolicyCatalog($State,$Capabilities) {
  foreach($stage in @('Routine','Repair','Complex')){
    $model=$State.Controls[$stage+'Model'];$effort=$State.Controls[$stage+'Effort']
    $selected=[string]$model.SelectedValue
    if(-not$selected){$selected=[string]$State.Policy.($stage+'Model')}
    $previous=[string]$effort.SelectedItem
    if(-not$State.Initialized){$previous=[string]$State.Policy.($stage+'Effort')}
    $entries=@(foreach($group in @($Capabilities.Models|Where-Object{-not(Get-PMMAnalysisValue $_ hidden $false)}|Group-Object model)){
      if($group.Count -ne 1){continue}
      $item=$group.Group[0]
      [pscustomobject]@{Value=[string]$item.model;Label=[string]$item.model;Available=$true;Efforts=@($item.supportedReasoningEfforts|ForEach-Object{$_.reasoningEffort})}
    })
    $match=@($entries|Where-Object{$_.Value -ieq $selected})
    if($match.Count -eq 1){$selected=$match[0].Value}else{
      $entries+=,[pscustomobject]@{Value=$selected;Label=($selected+(L ' (not detected)' ' (no detectado)'));Available=$false;Efforts=@()}
    }
    $model.Tag.Updating=$true
    $model.ItemsSource=$entries;$model.SelectedValue=$selected
    $model.Tag.Updating=$false
    Update-PMMPolicyEfforts $model
    if($previous -in @($effort.ItemsSource)){$effort.SelectedItem=$previous}
  }
  $State.Initialized=$true
  $State.Status.Text=(L 'Last account check: ' 'Ultima comprobacion: ')+$Capabilities.Plan+'; '+$Capabilities.Utc+'. '+(L 'Choose a detected model and one of its supported reasoning levels.' 'Elige un modelo detectado y uno de sus niveles de razonamiento disponibles.')
}
function Complete-PMMPolicyRefresh([string]$ErrorMessage='') {
  $state=$Script:PMMAIPolicyRefreshState
  $Script:PMMAIPolicyRefreshState=$null
  if(-not$state -or $state.Closed){return}
  $state.Refresh.IsEnabled=$true
  if($ErrorMessage){$state.Status.Text=$ErrorMessage;return}
  try{Update-PMMPolicyCatalog $state (Read-PMMJsonFile (Join-PMMPath 'State' 'ai-capabilities.json'))}
  catch{$state.Status.Text=$_.Exception.Message}
}

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
    $model=[Windows.Controls.ComboBox]::new();$model.DisplayMemberPath='Label';$model.SelectedValuePath='Value';$model.IsEditable=$false;$model.Width=230;$model.Margin=[Windows.Thickness]::new(3)
    $effort=[Windows.Controls.ComboBox]::new();$effort.Width=95;$effort.Margin=[Windows.Thickness]::new(3)
    $model.Tag=@{Effort=$effort;Updating=$false}
    $model.Add_SelectionChanged({param($sender,$eventArgs) Update-PMMPolicyEfforts $sender})
    [void]$row.Children.Add($label);[void]$row.Children.Add($model);[void]$row.Children.Add($effort);[void]$v.body.Children.Add($row)
    $controls[$stage+'Model']=$model;$controls[$stage+'Effort']=$effort
  }
  $api=[Windows.Controls.CheckBox]::new();$api.IsChecked=$policy.AllowApiBilling;$api.Content=L 'Allow separately billed API requests' 'Permitir peticiones API facturadas por separado';$api.Margin=[Windows.Thickness]::new(4);[void]$v.body.Children.Add($api)
  $status=[Windows.Controls.TextBlock]::new();$status.TextWrapping='Wrap';$status.Margin=[Windows.Thickness]::new(4)
  [void]$v.body.Children.Add($status)
  $refresh=[Windows.Controls.Button]::new();$refresh.Content=L 'Check plan and models' 'Comprobar plan y modelos';$refresh.Margin=[Windows.Thickness]::new(3)
  $state=@{Policy=$policy;Controls=$controls;Api=$api;Status=$status;Window=$v.window;Refresh=$refresh;Closed=$false;Initialized=$false}
  $v.window.Tag=$state
  $v.window.Add_Closed({param($sender,$eventArgs)$sender.Tag.Closed=$true})
  $refresh.Tag=$state
  $capPath=Join-PMMPath 'State' 'ai-capabilities.json'
  try{
    $cap=if(Test-Path -LiteralPath $capPath){Read-PMMJsonFile $capPath}else{[pscustomobject]@{Models=@();Plan='Unknown';Utc=''}}
    Update-PMMPolicyCatalog $state $cap
    if(-not(Test-Path -LiteralPath $capPath)){$status.Text=L 'Check plan and models to load the available choices. Existing preferences are preserved.' 'Comprueba el plan y los modelos para cargar las opciones disponibles. Se conservan tus preferencias.'}
  }catch{$status.Text=$_.Exception.Message}
  $refresh.Add_Click({param($sender,$eventArgs)
    $state=$sender.Tag
    try{
      $folder=Join-PMMPath 'Cache' 'DeepRequests';[void][IO.Directory]::CreateDirectory($folder)
      $path=Join-Path $folder ([guid]::NewGuid().ToString('N')+'.json')
      Write-PMMJsonAtomic $path @{Action='RefreshAI'}
      $Script:PMMAIPolicyRefreshState=$state
      $state.Refresh.IsEnabled=$false
      $state.Status.Text=L 'Checking account and models...' 'Consultando cuenta y modelos...'
      $started=Start-PMMBackgroundOperation -Operation DeepSource -RequestPath $path -OnSuccess {param($r)Complete-PMMPolicyRefresh} -OnFailure {param($message)Complete-PMMPolicyRefresh $message}
      if(-not$started){Complete-PMMPolicyRefresh (L 'Another operation is running. Retry when it finishes.' 'Hay otra operacion en curso. Reintenta cuando termine.')}
    }catch{Complete-PMMPolicyRefresh $_.Exception.Message}
  })
  $save=[Windows.Controls.Button]::new();$save.Content=L 'Save policy' 'Guardar politica';$save.Margin=[Windows.Thickness]::new(3)
  $save.Tag=$state
  $save.Add_Click({param($sender,$eventArgs)
    $state=$sender.Tag;$policy=$state.Policy;$controls=$state.Controls
    try{
      $policy.Profile=[string]$controls.Profile.SelectedValue;$policy.MaxStage=[string]$controls.MaxStage.SelectedValue;$policy.AllowApiBilling=[bool]$state.Api.IsChecked
      foreach($stage in @('Routine','Repair','Complex')){
        $entry=$controls[$stage+'Model'].SelectedItem
        if($entry -and $entry.Available){
          $selectedEffort=[string]$controls[$stage+'Effort'].SelectedItem
          if(-not$selectedEffort){throw (L ('Choose a supported reasoning level for '+$stage+'.') ('Elige un nivel de razonamiento disponible para '+$stage+'.'))}
          $policy.($stage+'Model')=[string]$entry.Value;$policy.($stage+'Effort')=$selectedEffort
        }
      }
      Save-PMMAIPolicy $policy;$state.Window.Close()
    }catch{$state.Status.Text=$_.Exception.Message}
  })
  [void]$v.actions.Children.Add($refresh);[void]$v.actions.Children.Add($save)
  [void]$v.window.ShowDialog()
}
