# Beacon

A personal iOS client for [The Array](https://array.baldlygo.uk) — a Raspberry Pi-based knowledge system. Built with SwiftUI, styled with a Mondrian-inspired design system.

> **Note:** This app is tightly coupled to a specific backend infrastructure (The Array). It won't run out of the box without that setup, but the on-device AI integration may be useful as a reference.

---

## Features

- **Chat** — conversational AI via Claude Haiku (cloud) or Gemma 4 E4B (on-device)
- **Voice** — record or import audio and transcribe entirely on-device via WhisperKit
- **Tasks** — view and manage tasks from The Array's PM system
- **Files** — browse and attach files from The Array's knowledge base
- **PM Mode** — structured project management check-in workflow (`/pm`)
- **Log Mode** — end-of-session logging to The Array's sessions database (`/log`)

---

## On-Device AI

The interesting technical part of this project is the on-device inference stack:

### Chat — LiteRT-LM + Gemma 4 E4B
- Runtime: [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) (Google's edge inference framework, Swift API)
- Model: `litert-community/gemma-4-E4B-it-litert-lm` (~3.7 GB, downloaded at runtime)
- Backend: **CPU only** — GPU backend requires iOS memory entitlements not available on a free developer account and causes `EXC_BAD_ACCESS` without them (~3.4 GB resident vs ~961 MB on CPU)
- KV cache: 8192 tokens max
- Model stored in Application Support, survives app rebuilds

### Transcription — WhisperKit
- Runtime: [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Argmax)
- Model: `large-v3-v20240930_626MB` (~630 MB, downloaded automatically on first use)
- No length limit — WhisperKit chunks audio internally
- Supports any AVFoundation-readable format (m4a, mp3, wav, aiff)

### Key implementation notes
- LiteRT-LM's `ConversationConfig` takes `initialMessages` separately from the current turn — if you add the user message to history before calling `sendMessage`, you must `.dropLast()` to avoid sending it twice
- LiteRT-LM uses `.model` role for assistant turns, not `.assistant`
- Engine self-heals after a null return (unloads and reinitialises on next call)
- PM/Log workflows always route to Claude — their prompts exceed Gemma's KV cache

---

## Requirements

- Xcode 16+
- iOS 17+ device (not Simulator — LiteRT-LM requires real hardware)
- Anthropic API key
- A running instance of The Array backend (or a compatible API)

## SPM Dependencies

- [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) — on-device Gemma inference
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) — on-device audio transcription

---

## Setup

1. Clone the repo and open `Beacon.xcodeproj` in Xcode
2. Add your provisioning profile under Signing & Capabilities
3. Build and run on a physical device
4. Add your Anthropic API key in the System tab
5. Point the Array API URL to your backend in `ArrayService.swift`
6. Optionally download the Gemma model (~3.7 GB) from the System tab

---

*Built for personal use. Shared as a reference for on-device AI on iOS.*
