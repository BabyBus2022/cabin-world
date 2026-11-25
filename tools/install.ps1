param([string]$Root = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$node = Join-Path $Root 'runtime/node.exe'
$tool = Join-Path $Root 'tools/setup.mjs'
function Invoke-Setup([string[]]$Arguments) {
    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $result = @(& $node $tool @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) { throw ($result -join [Environment]::NewLine) }
        return ($result -join '').Trim()
    } finally { $ErrorActionPreference = $prev }
}
function Run-Setup {
    $stage = Invoke-Setup @('status')
    if ($stage -eq 'fresh') { [void](Invoke-Setup @('fresh')); return 0 }
    if ($stage -eq 'ready') { return 0 }
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.Application]::EnableVisualStyles()
    if ($stage -eq 'ask') {
        $answer = [Windows.Forms.MessageBox]::Show("你有以前的小屋世界存档，想接着玩吗？`n`n有旧存档，选「是」并选择原来的游戏文件夹。`n第一次玩，选「否」安装完整的 1.2。",'小屋世界 1.2 · 安装','YesNoCancel','Question','Button3')
        if ($answer -eq 'Cancel') { return 2 }
        if ($answer -eq 'No') { [void](Invoke-Setup @('fresh')); return 0 }
        $picker = New-Object Windows.Forms.FolderBrowserDialog
        $picker.Description = '请选择原来的小屋世界文件夹（里面有 CabinWorld.exe）。请先保存并退出旧游戏和本地桥。'
        $picker.ShowNewFolderButton = $false
        try {
            do {
                if ($picker.ShowDialog() -ne 'OK') { return 2 }
                try { $stage = Invoke-Setup @('import',$picker.SelectedPath) }
                catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'无法读取旧存档') }
            } until ($stage -eq 'choose')
        } finally { $picker.Dispose() }
    }
    $confirmed = & (Join-Path $Root 'choose-modules.ps1') -Root $Root
    if ($confirmed -ne $true) { return 2 }
    [void](Invoke-Setup @('finish'))
    return 0
}
try {
    # A second launcher waits for the same install session and then reads its saved state.
    $sha = [Security.Cryptography.SHA256]::Create()
    $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Root).ToUpperInvariant())))
    $mutex = New-Object Threading.Mutex($false, ('Local\CabinWorld-Setup-' + $key))
    try {
        try { [void]$mutex.WaitOne() } catch [Threading.AbandonedMutexException] {}
        try { $code = Run-Setup } finally { $mutex.ReleaseMutex() }
    } finally { $mutex.Dispose(); $sha.Dispose() }
    exit $code
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'小屋世界安装')
    exit 1
}

