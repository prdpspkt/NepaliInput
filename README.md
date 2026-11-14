# Nepali Input 🇳🇵

**Google Input Tools for macOS with On-Device Machine Learning** — Type in English phonetically, get real-time transliteration in Nepali (and 17 more languages) with native Devanagari numerals, smart adaptive learning, and offline support.

A native macOS Input Method Editor (IME) that works system-wide in every application. Just type phonetically (e.g., type "namaste" → "नमस्ते", "123" → "१२३").

## Features

- **System-wide** — Works in Safari, Notes, VS Code, Pages, WhatsApp, everywhere
- **On-Device Adaptive Machine Learning (ML)**:
  - **Vocabulary Learning**: Learns your preferred words and custom names each time you type.
  - **Contextual Bigram Modeling**: Learns word pair associations (e.g., typing "pani" after "khana" ranks "पानी" over "पनि").
  - **Recency Decay Scoring**: Frequently and recently used words are boosted to position 1.
  - **100% Private & On-Device**: Stored locally in Application Support; zero data transmitted.
- **Offline Phonetic Engine Fallback** — Continue typing seamlessly even when offline or disconnected from the internet.
- **Native Devanagari Numerals** — Numbers 0–9 output as Devanagari numerals (०, १, २, ३, ४, ५, ६, ७, ८, ९) with an instant menu bar toggle for Hindu-Arabic numerals.
- **Native Menu Bar Icon** — Displays "ने" (first letter of नेपाली) in the macOS menu bar.
- **18 languages supported** — Nepali, Hindi, Bengali, Tamil, Telugu, Marathi, Gujarati, Kannada, Malayalam, Punjabi, Urdu, Arabic, Persian, Russian, Greek, Thai, Amharic, Sinhalese.
- **Real-time suggestions** — Candidate window appears as you type.
- **Native macOS UI** — Integrated system candidate panel with dark mode support.
- **Lightweight** — Runs as a background process, no dock icon.

## Quick Start

### Build & Install

```bash
./scripts/install.sh
```

The script builds the app, installs it to `~/Library/Input Methods`, signs it for your Mac, registers it with macOS, and enables the input source. To remove it, run `./scripts/install.sh --uninstall`.

If **Nepali Input** doesn't appear in System Settings → Keyboard → Input Sources, log out and back in once.

### Activate manually (if needed)

1. Open **System Settings → Keyboard → Input Sources**
2. Click **Edit...** → **+** (Add input source)
3. Search for **"Nepali Input"** and add it
4. Switch to Nepali Input from the menu bar input source menu (**ने** icon or `Ctrl+Space`)

### Start Typing!

Open any app and start typing phonetically. Transliteration suggestions appear inline and in the candidate window.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **Space** | Accept the top suggestion + insert space |
| **Enter / Return** | Accept the top suggestion without space |
| **0-9 (Idle)** | Insert native numerals (०, १, २, ...) |
| **1-9 (Composing)** | Select suggestion by number |
| **Escape** | Cancel current composition |
| **↑ / ↓** | Navigate suggestions |
| **Tab** | Accept the top suggestion |

## Menu Options

Right-click the **ने** icon in the menu bar to:
- **Devanagari Numerals (०–९)**: Toggle between native Devanagari numerals and standard Hindu-Arabic numerals (0–9)
- **Adaptive Learning (ML)**: Enable or disable machine learning re-ranking
- **Learned Words**: View total learned vocabulary count
- **Reset Learned Vocabulary**: Reset your personalized ML dictionary
- **Language**: Switch between supported languages

## Supported Languages

| Language | Native Name | Icon | Example |
|----------|-------------|------|---------|
| Nepali | नेपाली | ने | namaste → नमस्ते, 123 → १२३ |
| Hindi | हिन्दी | हि | namaste → नमस्ते, 123 → १२३ |
| Bengali | বাংলা | বা | ami → আমি, 123 → ১২३ |
| Tamil | தமிழ் | த | vanakkam → வணக்கம் |
| Telugu | తెలుగు | తె | namaskaram → నమస్కారం |
| Marathi | मराठी | म | namaskar → नमस्कार |
| Gujarati | ગુજરાતી | ગુ | kem cho → કેમ છો |
| Kannada | ಕನ್ನಡ | ಕ | namaskara → ನಮಸ್ಕಾರ |
| Malayalam | മലയാളം | മ | namaskkaram → നമസ്ക്കാരം |
| Punjabi | ਪੰਜਾਬੀ | ਪੰ | sat sri akal → speed ਸ੍ਰੀ ਅਕਾਲ |
| Urdu | اردو | ار | salam → سلام |
| Arabic | العربية | عر | marhaba → مرحبا |
| Persian | فارسی | فا | salam → سلام |
| Russian | Русский | Ру | privet → привет |
| Greek | Ελληνικά | Ελ | geia sou → γεια σου |
| Thai | ไทย | ไท | sawasdee → สวัสดี |
| Amharic | አማርኛ | አማ | selam → ሰላም |
| Sinhalese | සිංහල | සි | ayubowan → ආයුබෝවන් |

## Development

```bash
make clean      # Clean build artifacts
make build      # Build app bundle
make install    # Install to ~/Library/Input Methods
make uninstall  # Remove installed app
make reinstall  # Rebuild and reinstall
```

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

## License

MIT
