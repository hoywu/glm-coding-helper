# GLM Coding Helper - Pipeline Backend GUI Launcher
# Usage: powershell -File start-backend-pipeline-gui.ps1
#   or double-click start-backend-pipeline-gui.cmd
# 弹 Tk 窗口实时显示后端状态、最近识别结果、worker 启动日志

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

Write-Host "GLM Coding Helper - Pipeline Backend (GUI)" -ForegroundColor Cyan
Write-Host ""

# ── 查找 Python venv ──
$Python = ""
if (Test-Path "$Root\venv\Scripts\python.exe") {
    $Python = "$Root\venv\Scripts\python.exe"
} elseif (Test-Path "$Root\.venv_paddle_gpu\Scripts\python.exe") {
    $Python = "$Root\.venv_paddle_gpu\Scripts\python.exe"
} elseif (Test-Path "$Root\.venv_paddle\Scripts\python.exe") {
    $Python = "$Root\.venv_paddle\Scripts\python.exe"
}else {
    Write-Host "[失败] 未找到 Python 虚拟环境，请先运行安装脚本。" -ForegroundColor Red
    Write-Host "[FAIL] No Python venv found. Run setup first (one-click-start.cmd / install-env.cmd)." -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Write-Host "[信息] 使用 Python: $Python" -ForegroundColor Gray

# ── 依赖检查 (pipeline 依赖 + tkinter) ──
$depsCheck = & $Python -c "import fastapi, uvicorn, psutil, tkinter" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[警告] 当前后端环境缺少依赖 (fastapi/uvicorn/psutil/tkinter)。" -ForegroundColor Yellow
    Write-Host "[WARN] Missing backend dependencies. Environment needs repair." -ForegroundColor Yellow
    Write-Host ""

    $setupScript = "$Root\scripts\setup_backend.ps1"
    if (Test-Path $setupScript) {
        Write-Host "是否自动安装缺失的依赖？"
        Write-Host "Install missing dependencies automatically?"
        $choice = Read-Host "输入 1 自动安装 / Enter 退出 (1=install / Enter=exit)"
        if ($choice -eq "1") {
            Write-Host "[信息] 正在安装 pipeline 依赖..." -ForegroundColor Cyan
            $env:PYTHONUTF8 = "1"
            $env:PYTHONIOENCODING = "utf-8"
            & $Python -m pip install fastapi "uvicorn[standard]" psutil --quiet
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[失败] 自动安装失败，请手动运行: install-env.cmd" -ForegroundColor Red
                Read-Host "按 Enter 退出"
                exit 1
            }
            Write-Host "[完成] 依赖安装成功" -ForegroundColor Green
        } else {
            Write-Host "请手动运行 install-env.cmd 或 pip install fastapi uvicorn psutil 后重试。" -ForegroundColor Yellow
            Read-Host "按 Enter 退出"
            exit 1
        }
    } else {
        Write-Host "请手动运行: $Python -m pip install fastapi uvicorn psutil" -ForegroundColor Yellow
        Read-Host "按 Enter 退出"
        exit 1
    }
}

# ── 端口检查 ──
$portLines = netstat -ano | Select-String ":8888 .*LISTENING"
if ($portLines) {
    $line = $portLines[0].ToString().Trim()
    $parts = $line -split '\s+'
    $portPid = $parts[-1]

    $procName = ""
    $procCmd = ""
    try {
        $proc = Get-Process -Id $portPid -ErrorAction SilentlyContinue
        if ($proc) { $procName = $proc.ProcessName }
        $procCmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$portPid" -ErrorAction SilentlyContinue).CommandLine
    } catch {}

    Write-Host ""
    Write-Host "[警告] 端口 8888 已被占用，后端可能已经在运行。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "占用进程:" -ForegroundColor DarkYellow
    Write-Host "  PID      : $portPid"
    if ($procName) { Write-Host "  进程名   : $procName" }
    if ($procCmd) { Write-Host "  命令行   : $procCmd" }
    Write-Host ""
    Write-Host "请选择:"
    Write-Host "  1 - 关闭该进程并重新启动后端"
    Write-Host "  Enter - 不处理，直接退出"
    Write-Host ""

    $choice = Read-Host "输入 (Input)"
    if ($choice -eq "1") {
        Write-Host "[信息] 正在关闭 PID $portPid ..." -ForegroundColor Cyan
        Stop-Process -Id $portPid -Force -ErrorAction SilentlyContinue
        Start-Sleep 3
        Write-Host "[完成] 已关闭。" -ForegroundColor Green
    } else {
        exit 1
    }
}

Write-Host "[信息] 启动 GUI 窗口，后端会在窗口中自动拉起。" -ForegroundColor Green
Write-Host "[提示] 关闭窗口会同时停止后端子进程。" -ForegroundColor DarkYellow
Write-Host ""

$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

& $Python "$Root\backend\gui.py"
