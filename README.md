# 智谱 GLM Coding Plan 助手 + 本地自动验证码

油猴脚本 + 本地 CPU/GPU OCR 后端，支持 GLM Coding Plan 流程辅助和中文点选验证码自动识别。

## 功能

- Tampermonkey 用户脚本，处理 GLM Coding Plan 页面流程
- 本地 HTTP 后端，接收验证码截图并返回点击坐标
- YOLO 检测 3 个候选字框
- PP-OCRv5 CPU/GPU 识别
- prompt-constrained OCR：每个框只在提示词 3 个字里做选择
- 自动检测 GPU，自动回退 CPU
- CPU worker 数自动估算，也支持手动设置
- Windows 一键 bootstrap，适合没有 Python 环境的新手



## 致谢

本项目的油猴前端脚本是在 Greasy Fork 用户 `mumumi` 的《GLM Coding Plan抢购助手》基础上二次开发而来：

https://greasyfork.org/zh-CN/scripts/572157-glm-coding-plan%E6%8A%A2%E8%B4%AD%E5%8A%A9%E6%89%8B

感谢原作者长期维护和分享。原脚本采用 GNU GPLv3 许可证；本仓库继续保留相同许可证声明，并在其基础上增加本地 CPU/GPU OCR 后端、自动验证码识别和开源部署脚本。

## 演示

https://github.com/user-attachments/assets/e1a56d07-5c4d-4aa1-a567-909dd25bd037

## 快速开始

第一次使用，打开 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap_windows.ps1 -Target auto
```

启动后端：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start_backend.ps1 -Mode auto
```

安装用户脚本：

```text
scripts/userscripts/glm-coding-helper.user.js
```

用 Tampermonkey 新建脚本，把该文件内容粘进去并保存。

## 手动模式

强制 CPU：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start_backend.ps1 -Mode cpu
```

强制 GPU：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start_backend.ps1 -Mode gpu
```

指定 CPU worker：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start_backend.ps1 -Mode cpu -CpuWorkers 3
```

无 GUI：

```powershell
python scripts\tools\start_backend.py --headless --mode auto
```

## 健康检查

```powershell
Invoke-RestMethod http://127.0.0.1:8888/health
```

返回内容里会包含当前后端配置，例如是否使用 GPU、CPU worker 数、YOLO device、OCR model 等。

## 模型文件

默认检测权重路径：

```text
models/weights/yolo-captcha-detector.pt
```

也可以用环境变量覆盖：

```powershell
$env:CNCAPTCHA_DETECTOR_PATH="D:\path\to\best.pt"
```

## 文档

更多配置见：

```text
docs/backend_config.md
```

## 说明

本项目用于本地 OCR、自动化辅助和技术研究。请遵守目标网站服务条款和当地法律法规，自行承担使用风险。
