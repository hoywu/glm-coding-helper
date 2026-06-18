param(
    [ValidateSet("auto", "cpu", "gpu")]
    [string]$Target = "auto",
    [int]$Port = 8888,
    [string[]]$PipArg = @()
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

function Assert-RequiredFiles {
    $required = @(
        "scripts\bootstrap_windows.ps1",
        "scripts\start_backend.ps1",
        "scripts\setup_backend.py",
        "requirements-backend-cpu.txt",
        "requirements-backend-gpu.txt"
    )
    $missing = @()
    foreach ($rel in $required) {
        if (-not (Test-Path (Join-Path $Root $rel))) {
            $missing += $rel
        }
    }
    if ($missing.Count -gt 0) {
        Write-Host "[FAIL] Release package is incomplete. Missing files:" -ForegroundColor Red
        foreach ($item in $missing) {
            Write-Host "       - $item" -ForegroundColor Red
        }
        Write-Host "Please re-extract the full latest release zip and retry." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
}

function Test-PythonImports {
    param(
        [string]$PythonPath,
        [string]$Code
    )
    if (-not $PythonPath -or -not (Test-Path $PythonPath)) { return $false }
    try {
        & $PythonPath -c $Code *> $null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Has-NvidiaGpu {
    $nvidia = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvidia) { return $false }
    & nvidia-smi -L *> $null
    return $LASTEXITCODE -eq 0
}

function Invoke-Bootstrap {
    param(
        [string]$BootstrapTarget,
        [string]$PythonPath
    )
    $argsList = @("-Target", $BootstrapTarget)
    if ($PythonPath -and (Test-Path $PythonPath)) {
        Write-Host "Existing backend environment failed import checks. Recreating it..."
        $argsList += "-Recreate"
    }
    foreach ($arg in $PipArg) {
        $argsList += "-PipArg"
        $argsList += $arg
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\bootstrap_windows.ps1" @argsList
    return $LASTEXITCODE
}

Assert-RequiredFiles

$InstallTarget = $Target
if ($InstallTarget -eq "auto") {
    $InstallTarget = if (Has-NvidiaGpu) { "gpu" } else { "cpu" }
}

$CpuPython = Join-Path $Root ".venv_paddle\Scripts\python.exe"
$GpuPython = Join-Path $Root ".venv_paddle_gpu\Scripts\python.exe"
$ImportCode = "import ultralytics, paddleocr, paddlex, cv2, PIL, numpy"

$SelectedPython = if ($InstallTarget -eq "gpu") { $GpuPython } else { $CpuPython }
$Ready = Test-PythonImports $SelectedPython $ImportCode

if (-not $Ready) {
    Write-Host "Backend environment is missing or incomplete (PIL/cv2/numpy etc). Installing $InstallTarget environment..."
    $bootstrapExit = Invoke-Bootstrap -BootstrapTarget $InstallTarget -PythonPath $SelectedPython
    $SelectedPython = if ($InstallTarget -eq "gpu") { $GpuPython } else { $CpuPython }
    $Ready = Test-PythonImports $SelectedPython $ImportCode

    if (($bootstrapExit -ne 0 -or -not $Ready) -and $Target -eq "auto" -and $InstallTarget -eq "gpu") {
        Write-Host "[WARN] GPU bootstrap failed or remained incomplete. Falling back to CPU environment..." -ForegroundColor Yellow
        $InstallTarget = "cpu"
        $SelectedPython = $CpuPython
        $bootstrapExit = Invoke-Bootstrap -BootstrapTarget "cpu" -PythonPath $SelectedPython
        $Ready = Test-PythonImports $SelectedPython $ImportCode
    }

    if (-not $Ready) {
        Write-Host "[FAIL] Backend environment repair failed. Required deps still missing." -ForegroundColor Red
        if ($Target -eq "auto") {
            Write-Host "       Auto mode already attempted GPU/CPU fallback." -ForegroundColor Red
        }
        Write-Host "       Try re-extracting the latest release and rerun one-click-start.cmd." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

if ($Target -eq "auto" -and $InstallTarget -eq "gpu" -and -not (Test-PythonImports $CpuPython $ImportCode)) {
    Write-Host "CPU fallback environment is missing. Installing CPU environment for auto fallback..."
    $fallbackExit = Invoke-Bootstrap -BootstrapTarget "cpu" -PythonPath $CpuPython
    if ($fallbackExit -ne 0) {
        Write-Host "[WARN] CPU fallback environment installation failed. Auto mode will still try GPU first." -ForegroundColor Yellow
    }
}

$PipelineDepsOk = Test-PythonImports $SelectedPython "import fastapi, uvicorn, psutil"
if (-not $PipelineDepsOk) {
    Write-Host "[INFO] Pipeline backend deps (fastapi/uvicorn/psutil) not installed. Run start-backend-pipeline-gui.cmd to add them." -ForegroundColor Yellow
}

$StartMode = if ($Target -eq "auto") { "auto" } else { $InstallTarget }
Write-Host "Starting backend in $StartMode mode on port $Port..."
& powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\start_backend.ps1" -Mode $StartMode -Port $Port
