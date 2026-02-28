---
name: doubao-asr
description: "Transcribe audio files via ByteDance Volcengine Seed-ASR 2.0 (豆包录音文件识别模型2.0) API. Best-in-class Chinese speech recognition (Mandarin, Cantonese, dialects). Supports 13+ languages, speaker diarization, and files up to 5 hours. Use when the user needs to transcribe recorded audio files, or asks for Doubao/豆包/Volcengine/火山引擎 audio file transcription."
license: Apache-2.0
compatibility: "python3, requests"
metadata:
  author: vahn-xu
  version: "1.0.0"
  homepage: https://www.volcengine.com/docs/6561/1354868
  tags: asr, speech-to-text, chinese, volcengine, bytedance, doubao, transcription
  requires:
    bins: [python3]
    pip: [requests]
    env: [VOLCENGINE_API_KEY, VOLCENGINE_ACCESS_KEY_ID, VOLCENGINE_SECRET_ACCESS_KEY, VOLCENGINE_TOS_BUCKET]
---

# Doubao ASR / 豆包语音转写

Transcribe audio files via ByteDance Volcengine's **Seed-ASR 2.0 Standard** (豆包录音文件识别模型2.0-标准版) API. Best-in-class accuracy for Chinese (Mandarin, Cantonese, Sichuan dialect, etc.) and supports 13+ languages.

调用字节跳动火山引擎**豆包录音文件识别模型2.0-标准版**（Seed-ASR 2.0 Standard）转写音频文件。中文识别（普通话、粤语、四川话等方言）准确率业界领先，支持 13+ 种语言。

## Quick start

```bash
python3 {baseDir}/scripts/transcribe.py /path/to/audio.m4a
```

Defaults:

- Model: Seed-ASR 2.0 Standard / 豆包录音文件识别模型2.0-标准版
- Speaker diarization: enabled / 说话人分离：默认开启
- Output: stdout (transcript text with speaker labels / 带说话人标签的转写文本)

## Useful flags

```bash
python3 {baseDir}/scripts/transcribe.py /path/to/audio.m4a --out /tmp/transcript.txt
python3 {baseDir}/scripts/transcribe.py /path/to/audio.mp3 --format mp3
python3 {baseDir}/scripts/transcribe.py /path/to/audio.m4a --json --out /tmp/result.json
python3 {baseDir}/scripts/transcribe.py /path/to/audio.m4a --no-speakers  # disable speaker diarization / 关闭说话人分离
python3 {baseDir}/scripts/transcribe.py https://example.com/audio.mp3  # direct URL (skip upload)
```

## How it works

The Doubao API accepts audio via URL (not direct file upload). The script:

1. **Uploads audio to Volcengine TOS** (object storage) via presigned URL — audio stays within Volcengine infrastructure, no third-party services involved
2. Submits transcription task to Seed-ASR 2.0
3. Polls until complete (typically 1-3 minutes for a 10-min audio)
4. Returns transcript text

> **Privacy**: By default, audio is uploaded to your own Volcengine TOS bucket via presigned URL. No data is sent to third-party services.

You can also pass a direct audio URL as the argument to skip upload entirely:

```bash
python3 {baseDir}/scripts/transcribe.py https://your-bucket.tos.volces.com/audio.m4a
```

## Dependencies

- Python 3.9+
- `requests`: `pip install requests`

## Credentials setup

You need 4 environment variables. Follow these steps carefully — the guided setup below saves you 1-2 hours of digging through Volcengine docs.

你需要设置 4 个环境变量。按以下步骤操作——这份引导能帮你节省 1-2 小时翻文档踩坑的时间。

### Step 1: Doubao ASR API Key / 第一步：豆包 ASR API Key

1. 打开 https://console.volcengine.com/speech/new/（确认进入的是新版「豆包语音」控制台）
2. 左侧菜单 →「语音识别」
3. 点击「开通模型」，开通「录音文件识别2.0」
4. 点击页面右上角「API 调用」
5. 在 Step 1「获取 API Key」中，点击创建 API Key
6. 复制生成的 UUID 格式 Key

---

1. Open https://console.volcengine.com/speech/new/ (make sure you are in the new 'Doubao Speech' console)
2. Left sidebar → 'Speech Recognition'
3. Click 'Activate Model', activate 'Audio File Recognition 2.0'
4. Click 'API Call' button at the top-right of the page
5. In Step 1 'Get API Key', click to create an API Key
6. Copy the generated UUID-format key (e.g. `57e620a4-179c-4b3d-bd8d-990bd1f9a1e2`)

```bash
export VOLCENGINE_API_KEY="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Step 2: IAM Access Key / 第二步：创建 IAM 子用户和访问密钥

1. 打开 https://console.volcengine.com/iam/usermanage
2. 点「新建用户」，填写用户名（如 `doubao-asr`）
3. 访问方式确保勾选「编程访问」和「允许用户管理自己的API密钥」，其他选项保持默认即可
4. 点击确定，创建成功后页面会显示 Access Key ID（以 `AKLT` 开头）和 Secret Access Key，复制保存

> **提示**：这一步不需要添加任何 IAM 权限策略。权限将在 Step 3 通过 TOS 桶策略授予（仅限单桶读写）。
> 如需再次查看密钥，进入用户列表 → 点击子用户名 → 切换到「密钥」tab。

---

1. Open https://console.volcengine.com/iam/usermanage
2. Click 'Create User', enter username (e.g. `doubao-asr`)
3. Make sure 'Programmatic Access' and 'Allow user to manage own API keys' are checked. Leave all other options as default
4. Click confirm. The success page shows Access Key ID (starts with `AKLT`) and Secret Access Key — copy both

> **Note**: No IAM permission policies needed here — access will be granted via TOS bucket policy in Step 3 (single-bucket read/write only).
> Tip: To view keys again, go to user list → click sub-user name → switch to 'Keys' tab.

```bash
export VOLCENGINE_ACCESS_KEY_ID="AKLTxxxx..."
export VOLCENGINE_SECRET_ACCESS_KEY="xxxx..."
```

### Step 3: TOS Bucket / 第三步：开通并创建 TOS 存储桶

豆包 API 要求音频通过 URL 访问。TOS 对象存储提供安全的临时上传，数据留在火山引擎内部。

1. 打开 https://console.volcengine.com/tos
2. 首次进入会看到「开通对象存储」引导页，点击确认开通
3. 开通后如果页面没有自动跳转到管理控制台，请手动重新访问 https://console.volcengine.com/tos 进入
4. 在左侧菜单栏找到「桶列表」。如果看不到已创建的桶，检查页面顶部的项目选择器，切换到创建桶时所用的项目
5. 点击「创建桶」，输入桶名称，**根据服务器位置选择区域**（见下方表格）
6. 创建完成后，点击桶名称进入桶控制面板
7. 左侧导航栏 →「权限管理」→「存储桶授权策略管理」→「创建策略」
8. 选择「文件夹读写」模板 → 下一步 → 授权用户选择「当前主账号」→ 资源范围选择「所有对象」→ 确定
9. 回到桶列表，复制桶名称

---

1. Open https://console.volcengine.com/tos
2. First-time users will see an 'Activate Object Storage' page — click to activate
3. If the page does not auto-redirect after activation, manually re-visit https://console.volcengine.com/tos
4. In the left sidebar, find 'Bucket List'. If you don't see your bucket, check the project selector at the top
5. Click 'Create Bucket', enter a bucket name and choose region based on server location (see table below)
6. After creation, click the bucket name to enter bucket dashboard
7. Left sidebar → 'Permission Management' → 'Bucket Authorization Policy' → 'Create Policy'
8. Select 'Folder Read/Write' template → Next → Authorized user: 'Current main account' → Resource scope: 'All objects' → Confirm
9. Go back to bucket list, copy the bucket name

**Region selection / 区域选择：**

| Server location / 服务器位置 | Recommended TOS region / 推荐 TOS 区域 | Region code |
|---|---|---|
| China mainland / 中国内地 | cn-beijing, cn-shanghai, cn-guangzhou | `cn-beijing` |
| Hong Kong / 香港 | cn-hongkong | `cn-hongkong` |
| Southeast Asia / 东南亚 | ap-southeast-1 (Singapore) | `ap-southeast-1` |
| US, Europe, other overseas / 美国、欧洲等海外 | **cn-hongkong** (recommended) | `cn-hongkong` |

> **Important**: If your server is **outside China mainland**, do NOT use `cn-beijing` / `cn-shanghai` — cross-border upload will be extremely slow (~15KB/s). Use `cn-hongkong` instead.
>
> **重要**：如果你的服务器在**中国大陆以外**，不要用 `cn-beijing` / `cn-shanghai`——跨境上传会非常慢（约 15KB/s）。请使用 `cn-hongkong`。

```bash
export VOLCENGINE_TOS_BUCKET="your_bucket_name"
export VOLCENGINE_TOS_REGION="cn-hongkong"  # see region table above / 见上方区域表
```

### Summary of all environment variables / 环境变量汇总

| Variable | Required | Description |
|---|---|---|
| `VOLCENGINE_API_KEY` | Yes | ASR API key (UUID format) from Speech console / 语音控制台的 API Key |
| `VOLCENGINE_ACCESS_KEY_ID` | Yes | IAM Access Key ID (starts with `AKLT`) / IAM 访问密钥 ID |
| `VOLCENGINE_SECRET_ACCESS_KEY` | Yes | IAM Secret Access Key / IAM 访问密钥 |
| `VOLCENGINE_TOS_BUCKET` | Yes | TOS bucket name / TOS 存储桶名称 |
| `VOLCENGINE_TOS_REGION` | No | TOS region (default: `cn-beijing`). Overseas servers MUST use `cn-hongkong` / 海外服务器必须用 `cn-hongkong` |

## Supported formats

WAV, MP3, MP4, M4A, OGG, FLAC — up to 5 hours, 512MB max.

支持格式：WAV、MP3、MP4、M4A、OGG、FLAC——最长 5 小时，最大 512MB。
