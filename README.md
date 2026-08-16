# SmartChat — a 100% free AI chat app

A ChatGPT-style app for iPhone, built with **SwiftUI**, that uses **completely free AI models** (no subscriptions, no in-app purchases). You only add a **free API key** — nothing else costs anything.

## Features (all free)

- Chat with free AI models and stream responses live (typewriter effect)
- **Two providers**: OpenRouter (`:free` models like DeepSeek, Llama 3.3, Qwen, Gemma 3, Phi-4) and Google Gemini free tier (gemini-2.5-flash)
- Markdown rendering with code blocks, copy + share on any message, regenerate answers
- Unlimited local chat history (SwiftData), automatic titles, swipe-to-delete
- Send images to the AI (vision-capable models)
- Settings: provider, model (or any custom model name), API key, temperature, max tokens, system prompt

## What this costs

| Item | Cost |
|---|---|
| Xcode/compiler (GitHub Actions) | Free |
| Apple Developer account | **Not needed** (sideloaded) |
| AI API keys (OpenRouter / Gemini free tier) | Free |
| Sideloading (Sideloadly / AltStore) | Free |

### The one trade-off
Free Apple IDs get **7-day certificates**. The app must be re-signed every 7 days. **AltStore** can auto-refresh it automatically as long as your iPhone is on the same Wi-Fi as a computer running AltServer. This is normal for every free sideloaded app.

## How to get the IPA (step by step)

### 1. Push this project to GitHub
1. Create a free account at https://github.com (if you don't have one).
2. Click **New repository**, name it e.g. `SmartChat`, keep it **Public** (public repos get unlimited free macOS build minutes), do **not** add a README (one already exists).
3. On your PC, in the project folder, run:
   ```
   git init
   git add .
   git commit -m "SmartChat app"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/SmartChat.git
   git push -u origin main
   ```

### 2. Let GitHub build the IPA
1. Open your repo → **Actions** tab → you'll see the **Build IPA** workflow running.
2. Wait ~5 minutes for it to finish (green check).
3. Open the finished run → **Artifacts** → download **SmartChat-IPA** → extract `SmartChat.ipa`.

(You can also re-build any time by going to Actions → Build IPA → **Run workflow**.)

### 3. Install it on your iPhone
1. Download **Sideloadly** (Windows/macOS) from https://sideloadly.io and install on your PC.
2. Connect your iPhone with a USB cable and trust the computer.
3. Open Sideloadly, drag `SmartChat.ipa` into it, enter your **Apple ID** and password (it's only used to sign — check "Advanced options" if you have issues).
4. Click **Start**. Wait for it to install.
5. On the iPhone: **Settings → General → VPN & Device Management** → tap your Apple ID → tap **Trust**.

Open SmartChat. Done!

## 4. Add your free AI key

- **Gemini (easiest):** go to https://aistudio.google.com, sign in with a Google account, click **Get API key** (top left), create one. It's free and includes gemini-2.5-flash.
- **OpenRouter (more model variety):** go to https://openrouter.ai, sign up free, create a key at https://openrouter.ai/keys. Pick any model marked `:free` — the app ships with several.

In the app: tap the gear icon → choose provider → paste your key → pick a model → Done. Then start chatting.

## 7-day refresh / making it last

- **AltStore** (https://altstore.io) can auto-refresh the app for you. Install AltStore the same way, then add SmartChat to it and enable "Background Refresh" — it will re-sign in the background when your phone is on the same Wi-Fi as your PC with AltServer running.
- The 7-day limit only applies to free Apple IDs. If you ever get a paid developer account ($99/yr), you can sign the same IPA for a year — but you don't need it to use this app.

## Project layout

```
SmartChat/
├── SmartChat/            Swift source code (SwiftUI + SwiftData)
│   ├── SmartChatApp.swift
│   ├── Models.swift      Conversation, Message, provider/model lists
│   ├── AIService.swift   OpenRouter + Gemini streaming API clients
│   ├── ChatView.swift    Chat UI + streaming logic
│   ├── ContentView.swift Conversation list
│   ├── SettingsView.swift
│   ├── MessageBubble.swift
│   └── MarkdownTextView.swift
├── project.yml           XcodeGen config (generates the Xcode project in CI)
└── .github/workflows/    Free macOS build → IPA
```

## Changing the app icon / name
- App name: edit `INFOPLIST_KEY_CFBundleDisplayName` in `project.yml`.
- App icon: add a 1024×1024 `AppIcon` image set under `SmartChat/Assets.xcassets/AppIcon.appiconset/` (search "AppIcon.appiconset Contents.json" for the format) and push — the build will pick it up.