# doubao-asr

> Agent Skill for transcribing audio files via ByteDance Volcengine **Seed-ASR 2.0** (豆包录音文件识别模型2.0)

Best-in-class Chinese speech recognition — Mandarin, Cantonese, Sichuan dialect, and 13+ languages. With speaker diarization, SRT subtitle export, and three recognition tiers (standard / express / offpeak), up to 5 hours / 512MB per file.

中文语音识别准确率业界领先——支持普通话、粤语、四川话等方言及 13+ 种语言。自带说话人分离、SRT 字幕导出、三档识别版本（标准/极速/闲时），单文件最长 5 小时 / 512MB。

## Why this skill?

Setting up Volcengine's Doubao Audio File Recognition 2.0 (豆包录音文件识别模型2.0, recorded audio → text) from scratch involves **4 environment variables across 3 different console pages** (Speech console, IAM, TOS). Without guidance, this typically takes 1-2 hours of doc-hunting and trial-and-error.

This skill provides **step-by-step bilingual setup instructions** (中英双语) baked into `SKILL.md`, so your AI agent can walk you through the entire process in ~10 minutes.

从零配置火山引擎豆包录音文件识别模型2.0（录音转文字）涉及 **3 个不同控制台页面的 4 个环境变量**。没有引导的话通常需要 1-2 小时翻文档踩坑。本 skill 在 `SKILL.md` 中内置了**中英双语分步引导**，AI agent 可以在约 10 分钟内带你完成全部配置。

## Install

### Claude Code

```bash
claude /install-skill https://github.com/vahnxu/doubao-asr
```

Or manually copy to `~/.claude/skills/doubao-asr/`.

### OpenClaw / ClawHub

Available on [ClawHub](https://clawhub.com) as `doubao-asr`.

### Manual

```bash
git clone https://github.com/vahnxu/doubao-asr.git
cd doubao-asr
pip install requests
python3 scripts/transcribe.py /path/to/audio.m4a
```

## Quick start

```bash
# Basic transcription
python3 scripts/transcribe.py /path/to/audio.m4a

# Save to file
python3 scripts/transcribe.py /path/to/audio.m4a --out /tmp/transcript.txt

# JSON output
python3 scripts/transcribe.py /path/to/audio.m4a --json --out /tmp/result.json

# Direct URL (skip upload)
python3 scripts/transcribe.py https://example.com/audio.mp3

# Disable speaker diarization
python3 scripts/transcribe.py /path/to/audio.m4a --no-speakers

# Export SRT subtitles (from per-utterance timestamps) / 导出 SRT 字幕
python3 scripts/transcribe.py /path/to/audio.m4a --srt --out /tmp/subs.srt

# Express tier (极速版): fastest — short audio returns in seconds, single-shot, audio ≤ 2h
python3 scripts/transcribe.py /path/to/audio.m4a --tier express

# Offpeak tier (闲时版): cheapest — async queue, completes within 24h, fetch later with --query
python3 scripts/transcribe.py /path/to/audio.m4a --tier offpeak            # prints request_id
python3 scripts/transcribe.py --query <request_id> --tier offpeak          # fetch result when ready
```

## Sample output

With speaker diarization enabled (default), the transcript is grouped by speaker:

带说话人分离（默认开启）时，转写文本按说话人分组输出：

```
Speaker 1:
今天这期节目我们聊聊语音识别的落地场景。

Speaker 2:
好的，我先分享一下我们团队最近的实践。
把会议录音自动转成纪要之后，整理时间大概省了一半。

Speaker 1:
这个效果确实不错，展开讲讲？
```

## Credentials

See the detailed setup guide in [SKILL.md](./SKILL.md#credentials-setup) — with step-by-step instructions for each environment variable.

| Variable | Required | Description |
|---|---|---|
| `VOLCENGINE_API_KEY` | Yes | ASR API key (UUID) from Speech console |
| `VOLCENGINE_ACCESS_KEY_ID` | Yes | IAM Access Key ID (starts with `AKLT`) |
| `VOLCENGINE_SECRET_ACCESS_KEY` | Yes | IAM Secret Access Key |
| `VOLCENGINE_TOS_BUCKET` | Yes | TOS bucket name |
| `VOLCENGINE_TOS_REGION` | Yes | TOS region code, must match bucket region. Overseas: e.g. `cn-hongkong`, `ap-southeast-1`; China: `cn-beijing` |

## Supported formats

WAV, MP3, MP4, M4A, OGG, FLAC — up to 5 hours, 512MB max.

## Troubleshooting / 常见问题

**Error**: `45000006 [Invalid audio URI] audio download failed` ([issue #1](https://github.com/vahnxu/doubao-asr/issues/1))
**Cause**: The Volcengine ASR service cannot read the audio object in your TOS bucket — the object's read permission is insufficient. / 火山 ASR 服务读取不到 TOS 桶里的音频对象——对象读权限不足。
**Solution**: Grant read access on the object so the ASR service can download it: set the object's ACL to public read, or open up the bucket's "read" permission without IP restriction. / 放开对象的读权限让 ASR 服务能下载该文件：把对象读权限设为公网读，或对「读」权限做不限制 IP 的放开。

More troubleshooting entries (403 upload errors, slow cross-border upload, wrong console API key, etc.) in [SKILL.md § Troubleshooting](./SKILL.md#troubleshooting--常见问题).

更多常见问题（上传 403、跨境上传慢、API Key 来源错误等）见 [SKILL.md § Troubleshooting](./SKILL.md#troubleshooting--常见问题)。

## License

Apache-2.0
