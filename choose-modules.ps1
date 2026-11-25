param([string]$Root = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
function Read-JsonFile($File) {
    Get-Content -Raw -Encoding UTF8 -LiteralPath $File | ConvertFrom-Json
}
$node = Join-Path $Root 'runtime/node.exe'
$cli = Join-Path $Root 'bridge/update-cli.mjs'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$planText = & $node $cli --plan
if ($LASTEXITCODE -ne 0) { throw '无法读取升级清单' }
$plan = ($planText -join [Environment]::NewLine) | ConvertFrom-Json
$file = $plan.file
$beforeText = if (Test-Path -LiteralPath $file) { [IO.File]::ReadAllText($file) } else { '' }
$form = New-Object Windows.Forms.Form
$form.Text = '小屋世界 1.2 · 选择更新'
$form.Size = New-Object Drawing.Size(660,680)
$form.MinimumSize = New-Object Drawing.Size(530,550)
$form.StartPosition = 'CenterScreen'
$title = New-Object Windows.Forms.Label
$title.Text = "勾选要使用的功能，可多选。保存后重新打开游戏及本地桥。"
$title.Dock = 'Top'; $title.Height = 42; $title.Padding = New-Object Windows.Forms.Padding(10)
$list = New-Object Windows.Forms.CheckedListBox
$list.Dock = 'Fill'; $list.CheckOnClick = $true; $list.IntegralHeight=$false
$help = New-Object Windows.Forms.Label
$help.Dock = 'Bottom'; $help.Height = 65; $help.Padding = New-Object Windows.Forms.Padding(8)
$buttons = New-Object Windows.Forms.FlowLayoutPanel
$buttons.Dock = 'Bottom'; $buttons.Height=42
$before = [ordered]@{}
foreach ($module in $plan.modules) {
    $on = $module.state -eq 'on'
    $before[$module.id]=$on
    [void]$list.Items.Add($module.name,$on)
}
$list.Add_SelectedIndexChanged({ if ($list.SelectedIndex -ge 0) { $help.Text=$plan.modules[$list.SelectedIndex].summary } })
$save = New-Object Windows.Forms.Button
$save.Text='保存选择';$save.Width=110
$save.Add_Click({
    try {
        $nowText = if (Test-Path -LiteralPath $file) { [IO.File]::ReadAllText($file) } else { '' }
        if ($beforeText -cne $nowText) { throw '选项已由其他程序更改，请重新打开窗口。' }
        $sets=@()
        for ($i=0;$i -lt $plan.modules.Count;$i++) {
            $id=$plan.modules[$i].id
            $on=$list.GetItemChecked($i)
            if ($on -ne $before[$id]) { $sets += '--set'; $sets += ($id+'='+$(if ($on){'on'}else{'off'})) }
        }
        if ($sets.Count) { $output = & $node $cli @sets; if ($LASTEXITCODE -ne 0) {throw '保存选择失败'} }
        $form.DialogResult = [Windows.Forms.DialogResult]::OK
        $form.Close()
    } catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'保存选项') }
})
$cancel=New-Object Windows.Forms.Button
$cancel.Text='取消';$cancel.Add_Click({$form.Close()})
$buttons.Controls.AddRange(@($save,$cancel))
$form.Controls.AddRange(@($list,$help,$buttons,$title))
return ($form.ShowDialog() -eq [Windows.Forms.DialogResult]::OK)
