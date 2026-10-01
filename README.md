# LSTranslate

An Ashita v4 addon for Final Fantasy XI that helps English-speaking and Chinese-speaking players communicate using Chinese/Pinyin ↔ English translation.

Developed and tested for CatsEyeXI.

## Features

- Translates incoming Chinese/Pinyin into English.
- Supports:
  - Tell
  - Linkshell 1
  - Linkshell 2
  - Party
- English → plain Pinyin replies.
- Understands common FFXI terminology such as PLD, RDM, BLU, NM, SP, DKP and other game terms.
- Incoming translation is display-only and does not automatically send chat messages.
- Designed to avoid translating normal English chat.
- No Chinese characters are required for outgoing messages.

## Requirements

- Ashita v4
- Python 3
- An OpenAI API key
- Internet connection

## Important - API Key

LSTranslate does **not** include an OpenAI API key.

Every user must create and use their **own OpenAI API key**.

Never share your API key with another player and never upload it to GitHub.

OpenAI API usage may have a separate cost and is not included with a ChatGPT subscription.

## Installation

### 1. Download LSTranslate

Download the repository and place the `LSTranslate` folder inside:

```text
Ashita/addons/LSTranslate/
```

### 2. Install Python

Install Python 3 for Windows.

During installation, enable the option to add Python to PATH if available.

### 3. Create an OpenAI API key

Create your own OpenAI API key from the OpenAI developer platform.

Copy the key and keep it private.

### 4. Save your API key

Open Command Prompt and run:

```cmd
setx OPENAI_API_KEY "YOUR_API_KEY_HERE"
```

Replace `YOUR_API_KEY_HERE` with your actual API key.

Do **not** put your API key inside `bridge.py`, `LSTranslate.lua`, or any other addon file.

After setting the key, open a new Command Prompt or restart Windows so applications can see the new environment variable.

### 5. Start the translation bridge

Run:

```text
start_hidden.vbs
```

The bridge runs locally in the background.

### 6. Load LSTranslate

Start FFXI through Ashita and enter:

```text
/addon load LSTranslate
```

You should see a message confirming that LSTranslate has loaded.

## Commands

```text
/lt t NAME message
```

Translate English into Pinyin and send it as a Tell.

Example:

```text
/lt t Player hello, are you coming?
```

```text
/lt r message
```

Reply to the last Tell using translated Pinyin.

```text
/lt l message
```

Translate and send to Linkshell.

```text
/lt p message
```

Translate and send to Party.

```text
/lt help
```

Show available commands.

## Safety

Incoming translation is passive/display-only.

LSTranslate does not automatically reply to players and is designed to avoid unsolicited `/tell`, `/say`, `/party`, or `/linkshell` messages.

Outgoing translated messages are only sent when the user explicitly uses an LSTranslate send command.

## Privacy

Chat text selected for translation is sent to the configured translation API for processing.

Do not use LSTranslate for information you do not want processed by the translation service.

## Version

Current version: **1.5.0**

## Author

**Harambe**

Built for the Final Fantasy XI / CatsEyeXI community.
