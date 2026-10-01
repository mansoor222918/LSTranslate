# LSTranslate

An Ashita v4 addon for Final Fantasy XI that helps English-speaking and Chinese-speaking players communicate using Chinese/Pinyin ↔ English translation.

Developed and tested for CatsEyeXI.

## Features

- Translates incoming Chinese/Pinyin into English.
- Supports Tell, Linkshell 1, Linkshell 2, and Party.
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

1. Download LSTranslate and place the `LSTranslate` folder inside `Ashita/addons/LSTranslate/`.
2. Install Python 3 for Windows and enable the option to add Python to PATH if available.
3. Create your own OpenAI API key from the OpenAI developer platform and keep it private.
4. Open Command Prompt and run: `setx OPENAI_API_KEY "YOUR_API_KEY_HERE"`
5. Open a new Command Prompt or restart Windows so applications can see the new environment variable.
6. Run `start_hidden.vbs` to start the local translation bridge in the background. If hidden startup does not work, run `start_bridge.bat` to see diagnostic messages.
7. Start FFXI through Ashita and enter: `/addon load LSTranslate`

## Commands

- `/lt <English>` — translate to Pinyin as a preview only; does not send.
- `/lt t NAME message` — translate and send one Tell.
- `/lt r message` — translate and send one Tell to the last teller.
- `/lt l message` — translate and send one Linkshell message.
- `/lt p message` — translate and send one Party message.
- `/lt help` — show available commands.
- `/lt debug` — toggle chat-mode debugging.

## Safety

Incoming translation is passive/display-only. LSTranslate does not automatically reply to players. Outgoing translated messages are only sent after the user explicitly uses an LSTranslate send command.

## Privacy

Chat text selected for translation is sent to the configured translation API for processing. Do not use LSTranslate for information you do not want processed by the translation service.

## Version

Current version: **1.5.0**

## Author

**Harambe**

Built for the Final Fantasy XI / CatsEyeXI community.
