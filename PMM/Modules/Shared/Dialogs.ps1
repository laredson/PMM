
function New-PMMThemedDialog([string]$Title){
    $dialog=[Windows.Window]::new();$dialog.Title=$Title;$dialog.Width=700;$dialog.MinHeight=230
    $dialog.SizeToContent='Height';$dialog.MaxHeight=[Windows.SystemParameters]::WorkArea.Height*0.9
    $dialog.WindowStartupLocation='CenterScreen';$dialog.ResizeMode='CanResizeWithGrip';$dialog.FontFamily='Segoe UI';$dialog.FontSize=13
    $dialog.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#081725')
    $dialog.Foreground=[Windows.Media.Brushes]::White
    $main=Get-Variable Window -ValueOnly -ErrorAction SilentlyContinue
    if($main){
        foreach($key in @($main.Resources.Keys)){$dialog.Resources[$key]=$main.Resources[$key]}
        $dialog.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'AppBackground')
        $dialog.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'PrimaryText')
        if($main.IsVisible){$dialog.Owner=$main;$dialog.WindowStartupLocation='CenterOwner'}
    }
    $layout=[Windows.Controls.DockPanel]::new();$layout.Margin=[Windows.Thickness]::new(22)
    $actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal';$actions.HorizontalAlignment='Right';$actions.Margin=[Windows.Thickness]::new(0,14,0,0)
    [Windows.Controls.DockPanel]::SetDock($actions,'Bottom');[void]$layout.Children.Add($actions)
    $scroll=[Windows.Controls.ScrollViewer]::new();$scroll.VerticalScrollBarVisibility='Auto'
    $body=[Windows.Controls.StackPanel]::new();$scroll.Content=$body;[void]$layout.Children.Add($scroll)
    $heading=[Windows.Controls.TextBlock]::new();$heading.Text=$Title;$heading.FontSize=22;$heading.FontWeight='SemiBold';$heading.TextWrapping='Wrap';$heading.Margin=[Windows.Thickness]::new(0,0,0,14);[void]$body.Children.Add($heading)
    $dialog.Content=$layout
    return @{window=$dialog;body=$body;actions=$actions}
}
function Show-PMMThemedMessage([object[]]$DialogArgs){
    $a=@($DialogArgs)
    if($a.Count -gt 0 -and $a[0] -is [Windows.Window]){$a=@($a|Select-Object -Skip 1)}
    $title='PMM';if($a.Count -gt 1){$title=[string]$a[1]}
    $buttons='OK';if($a.Count -gt 2){$buttons=[string]$a[2]}
    $view=New-PMMThemedDialog $title
    $text=[Windows.Controls.TextBlock]::new();$text.Text=[string]$a[0];$text.TextWrapping='Wrap'
    $card=[Windows.Controls.Border]::new();$card.Padding=[Windows.Thickness]::new(16);$card.CornerRadius=[Windows.CornerRadius]::new(7);$card.BorderThickness=[Windows.Thickness]::new(1)
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'CardBackground')
    $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty,'CardBorder');$card.Child=$text
    [void]$view.body.Children.Add($card)
    $names=switch($buttons){'YesNo'{@('No','Yes')};'YesNoCancel'{@('Cancel','No','Yes')};'OKCancel'{@('Cancel','OK')};default{@('OK')}}
    $dismiss=if($buttons -eq 'YesNo'){'No'}elseif($buttons -eq 'OK'){'OK'}else{'Cancel'}
    $state=@{result=$dismiss;window=$view.window}
    foreach($name in $names){
        $b=[Windows.Controls.Button]::new();$b.Content=if(Get-Command L -ErrorAction SilentlyContinue){switch($name){'Yes'{L 'Yes' 'Si'};'No'{'No'};'Cancel'{L 'Cancel' 'Cancelar'};default{L 'OK' 'Aceptar'}}}else{$name};$b.Tag=$name;$b.MinWidth=110;$b.Margin=[Windows.Thickness]::new(8,0,0,0)
        $b.IsCancel=($name -eq $dismiss);$b.IsDefault=($name -eq $dismiss)
        $b.Add_Click({param($sender,$eventArgs)$state.result=[string]$sender.Tag;$state.window.Close()}.GetNewClosure())
        [void]$view.actions.Children.Add($b)
    }
    [void]$view.window.ShowDialog()
    return [Windows.MessageBoxResult]([Enum]::Parse([Windows.MessageBoxResult],$state.result))
}
function Show-PMMThemedFormsMessage([object[]]$DialogArgs){
    $r=Show-PMMThemedMessage $DialogArgs
    return [Windows.Forms.DialogResult]([Enum]::Parse([Windows.Forms.DialogResult],$r.ToString()))
}
function Show-PMMStyledDialog($Dialog){
    if($Dialog -is [Windows.Window]){
        $main=Get-Variable Window -ValueOnly -ErrorAction SilentlyContinue
        if($main){
            foreach($key in @($main.Resources.Keys)){if(-not $Dialog.Resources.Contains($key)){$Dialog.Resources[$key]=$main.Resources[$key]}}
            $Dialog.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'AppBackground')
            $Dialog.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'PrimaryText')
        }
        $Dialog.FontFamily='Segoe UI'
    }elseif($Dialog -is [Windows.Forms.Form]){
        $Dialog.Font=[Drawing.Font]::new('Segoe UI',10)
        $main=Get-Variable Window -ValueOnly -ErrorAction SilentlyContinue
        $back='#081725';$front='#FFFFFF';$card='#102638';$border='#3474A4'
        if($main){try{$back=$main.FindResource('AppBackground').Color.ToString();$front=$main.FindResource('PrimaryText').Color.ToString();$card=$main.FindResource('CardBackground').Color.ToString();$border=$main.FindResource('CardBorder').Color.ToString()}catch{}}
        foreach($n in @('back','front','card','border')){$c=Get-Variable $n -ValueOnly;if($c.Length -eq 9){Set-Variable $n ('#'+$c.Substring(3))}}
        $colors=@{back=[Drawing.ColorTranslator]::FromHtml($back);front=[Drawing.ColorTranslator]::FromHtml($front);card=[Drawing.ColorTranslator]::FromHtml($card);border=[Drawing.ColorTranslator]::FromHtml($border)}
        function Set-PMMFormColors($Control){
            $Control.BackColor=$colors.back;$Control.ForeColor=$colors.front
            if($Control -is [Windows.Forms.TextBoxBase] -or $Control -is [Windows.Forms.ListControl]){$Control.BackColor=$colors.card}
            if($Control -is [Windows.Forms.Button]){$Control.FlatStyle='Flat';$Control.FlatAppearance.BorderColor=$colors.border;$Control.BackColor=$colors.card}
            foreach($child in $Control.Controls){Set-PMMFormColors $child}
        }
        Set-PMMFormColors $Dialog
    }
    return $Dialog.ShowDialog()
}
