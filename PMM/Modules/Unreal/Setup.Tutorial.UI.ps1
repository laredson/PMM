
function Show-PMMSetupTutorial {
    $language=L 'en' 'es'
    $path=Join-Path $Script:Root ('Documentation\UNREAL_SETUP.'+$language+'.md')
    $text=[IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
    $v=New-PMMThemedDialog (L 'Optional tools installation tutorial' 'Tutorial de instalacion de herramientas opcionales')
    $v.window.Width=860
    $v.window.Height=[Math]::Min(720,[Windows.SystemParameters]::WorkArea.Height*0.9)
    $v.window.SizeToContent='Manual'
    $document=[Windows.Documents.FlowDocument]::new();$document.FontFamily=[Windows.Media.FontFamily]::new('Segoe UI');$document.FontSize=14;$document.PagePadding=[Windows.Thickness]::new(12)
    foreach($line in $text -split "\r?\n"){
        $p=[Windows.Documents.Paragraph]::new();$p.Margin=[Windows.Thickness]::new(0,0,0,8)
        $display=$line
        if($line -match '^#{1,3} (.+)$'){$display=$Matches[1];$p.FontSize=19;$p.FontWeight='SemiBold';$p.Margin=[Windows.Thickness]::new(0,14,0,8)}
        [void]$p.Inlines.Add([Windows.Documents.Run]::new($display));[void]$document.Blocks.Add($p)
    }
    $viewer=[Windows.Controls.FlowDocumentScrollViewer]::new();$viewer.Document=$document;$viewer.IsToolBarVisible=$false;$viewer.VerticalScrollBarVisibility='Auto';$viewer.Height=[Math]::Max(180,$v.window.Height-180)
    $viewer.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'PrimaryText')
    $viewer.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'CardBackground')
    [void]$v.body.Children.Add($viewer)
    $close=[Windows.Controls.Button]::new();$close.Content=L 'Close' 'Cerrar';$close.MinWidth=110;$close.IsCancel=$true
    $close.Add_Click({$v.window.Close()}.GetNewClosure());[void]$v.actions.Children.Add($close)
    [void]$v.window.ShowDialog()
}
