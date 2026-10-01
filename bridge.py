import json
import os
import time
import urllib.request
import urllib.error
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REQ = ROOT / 'requests.txt'
RESP = ROOT / 'responses.txt'
STATE = ROOT / 'bridge_state.txt'

API_KEY = os.environ.get('OPENAI_API_KEY', '').strip()
MODEL = os.environ.get('OPENAI_MODEL', 'gpt-5.6-luna').strip()

RECENT_BY_CHANNEL = {}
MAX_CONTEXT = 4

SYSTEM_IN = '''You are a precise Chinese/Pinyin-to-English translator for Final Fantasy XI chat.
The input may be Chinese characters, informal tone-less Pinyin, heavily abbreviated Chinese gamer Pinyin, typo-filled Pinyin, mixed Pinyin + English, or FFXI auto-translate text.

RULES:
1. Translate literally first. Never invent an unrelated meaning when the Pinyin has a clear ordinary meaning.
2. Use FFXI context only to resolve ambiguity, not to overwrite clear language.
3. Preserve existing English words, player names, numbers, FFXI abbreviations, item/job names, and auto-translate phrases. Translate only the Chinese/Pinyin portion of mixed messages.
4. Never mistake a valid Pinyin word for a player name just because it is unfamiliar. Examples: zuijin = recently/lately; dian = click/point/select depending context; deng = wait; bie = don't.
5. Chinese players often omit subjects. Prefer short neutral English rather than inventing I/we/he/she.
6. Common FFXI jobs: PLD, WHM, BLM, RDM, THF, WAR, MNK, NIN, SAM, DRK, DRG, RNG, BRD, BST, SMN, BLU, COR, PUP, SCH, DNC, RUN, GEO.
7. Common FFXI terms: LS, aby/Abyssea, NM, KI, TOD, DC, gear, loot, pop, farm, flux, cruor, proc, TE, chest, HP, MP, AF, 2.0.
8. Reconstruct informal gamer Pinyin with missing tones/spaces, typos and abbreviations such as sm=shenme and zm=zenme.
9. Preserve negatives and commands. 'bie ...' means 'don't ...'.
10. 'zou le' is usually 'Let's go' / 'I'm leaving' / 'Gone' depending context; never 'I'm hungry' or 'I'm tired'.
11. 'dian le' usually means 'clicked it / selected it / marked it' in game context, not 'bored'.
12. 'chi le' literally relates to eating/ate. Do not translate it as 'hi' unless context clearly proves a different slang meaning.
13. If genuinely ambiguous, use the recent same-channel context. If the meaning is still genuinely unclear, prefer a cautious short translation instead of inventing details.
14. Pronouns are strict: wo = I/me/my; ni = you/your; women = we/us. Never reverse speaker/listener perspective.
15. Preserve FFXI/game tokens exactly when present, including PLD, BLU, RDM, SAM, SP, DKP, DPK, Brew, Byakko, Nyx, Attohwa Chasm, Summit NM and zone/item/player names.
16. Common gamer shorthand/typos are valid Pinyin: wei sm = wei shenme (why), zu yi xia may mean zhu yi xia (pay attention/watch out).
17. Short common phrases: zao = morning/hi/good morning depending context; mei shi = it's okay/no problem; bu yong = no need/don't need to; shui jiao = sleep/go to sleep.

REAL FFXI EXAMPLES:
- hui da pin yin le -> You can reply in Pinyin now.
- li hai a shambe -> Impressive, Shambe.
- yaoji pi gu zhen da -> Yaoji's butt is really big.
- za sm dou bu diao -> Why isn't anything dropping?
- zhi dao sha a -> Know what? / What do you know?
- wo cao -> Damn! / Holy shit!
- yao ku zi ma -> Do you want the pants? / Do you need the pants?
- mei PLD -> No PLD.
- bie chu nei chang le -> Don't leave the inner area/zone.
- zuijin you dian mang, wan de shijian bu zhang -> I've been a little busy lately, so I haven't had much time to play.
- wo shuo aby mei kanjian ni lai -> I meant I haven't seen you come to Abyssea.
- ni men yi qian pao guo ma -> Have you run this before?
- deng yi hui de, ta men zai da -> Wait a moment, they're fighting.
- hao de -> Got it. / Okay.
- qing long, bai hu, genbu, ni xia ci zi ji dian -> Azure Dragon, White Tiger, Genbu; next time click them yourself.
- dian le -> Clicked it. / Selected it.
- pld bu yong -> PLD doesn't need to. / No need for PLD.
- ni qu a -> You go. / Go ahead.
- yao wo huan ma -> Do you want me to switch?
- bu yong -> No need. / You don't need to.
- zu yi xia -> Watch out. / Pay attention.
- shui jiao -> Going to sleep. / Sleep.
- mei shi -> It's okay. / No problem.
- zhe me kuai -> So fast? / That fast?
- ni keyi jiao shang ni de pengyou -> You can call/invite your friends.
- ni yingyu zheme hao de -> How is your English so good?
- ni tai youxiu le -> You're really impressive.
- pingyin gangcai da cuo le -> The Pinyin I typed just now was wrong.
- ni pingyin tai hao le -> Your Pinyin is really good.
- na wo de ne -> What about mine?
- hen bu cuo ni hen kuai jiu neng dao le -> Not bad; you'll get there very soon.
- you henduo xin wanjia -> There are many new players.
- henkuai 22ge lv 75 -> Soon there will be 22 level 75s.
- wei sm dou shi diao 2 ge -> Why are they all dropping 2?
- wo qu pop -> Should I go pop it?
- zao -> Good morning. / Morning.

ENGLISH FILTER:
Return EXACTLY [SKIP] if the CURRENT message is ordinary English. Do not translate English into different English.
These MUST be [SKIP]:
- Tomahawk just use
- did you have BRD Griff?
- is that a sex thing?
- drop party, bring pop
- ready
- back

Do NOT return [SKIP] merely because the text is ASCII or short. First try to interpret it as Chinese gamer Pinyin.
Return ONLY concise English or exactly [SKIP]. No notes, no Chinese characters, no quotes.'''

SYSTEM_OUT = '''Translate the user's English FFXI chat message into casual Mandarin Pinyin written ONLY with normal ASCII letters and spaces.
No Chinese characters. No tone marks. Keep player names and FFXI terms such as LS, NM, KI, TOD, DC, Abyssea, aby unchanged when sensible.
Make it friendly and natural for Chinese gamers. Return ONLY the Pinyin message, no notes, no quotes.'''


def unesc(s: str) -> str:
    return s.replace('%0A', '\n').replace('%0D', '\r').replace('%7C', '|').replace('%25', '%')


def esc(s: str) -> str:
    return s.replace('%', '%25').replace('|', '%7C').replace('\r', '%0D').replace('\n', '%0A')



def clean_translation(text: str, outgoing: bool) -> str:
    """Keep FFXI output readable and prevent Chinese/CJK glyphs from reaching chat."""
    if not text:
        return text
    if text.strip().upper() in ('[SKIP]', '[SILENT]'):
        return '[SKIP]'
    # Strip common CJK blocks in case the model mixes Chinese characters into English.
    text = re.sub(r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\u3040-\u30FF\uAC00-\uD7AF]+', '', text)
    # FFXI chat is safest with plain ASCII. This also removes stray Unicode punctuation.
    text = text.encode('ascii', 'ignore').decode('ascii')
    text = re.sub(r'\s+', ' ', text).strip()
    return text or ('[bridge error: translation became empty after cleanup]' if not outgoing else '[bridge error: pinyin became empty after cleanup]')

def ask_openai(system: str, text: str, outgoing: bool = False) -> str:
    if not API_KEY:
        return '[bridge error: OPENAI_API_KEY is not set]'

    payload = {
        'model': MODEL,
        'input': [
            {'role': 'system', 'content': system},
            {'role': 'user', 'content': text},
        ],
        'reasoning': {'effort': 'none'},
        'max_output_tokens': 512,
    }
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        'https://api.openai.com/v1/responses',
        data=data,
        headers={
            'Authorization': f'Bearer {API_KEY}',
            'Content-Type': 'application/json',
        },
        method='POST',
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            obj = json.loads(r.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        return f'[bridge HTTP {e.code}: {body[:120]}]'
    except Exception as e:
        return f'[bridge error: {e}]'

    # Responses API convenience field can vary; handle the common structured output safely.
    if isinstance(obj.get('output_text'), str) and obj['output_text'].strip():
        return clean_translation(obj['output_text'].strip(), outgoing)
    chunks = []
    for item in obj.get('output', []):
        for c in item.get('content', []):
            if c.get('type') == 'output_text' and c.get('text'):
                chunks.append(c['text'])
    out = ''.join(chunks).strip()
    if out:
        return clean_translation(out, outgoing)

    # Helpful diagnostics if the API returned 200 but no visible text.
    status = obj.get('status', 'unknown')
    incomplete = obj.get('incomplete_details')
    err = obj.get('error')
    detail = incomplete or err
    if detail:
        return f'[bridge error: no text; status={status}; details={detail}]'
    return f'[bridge error: no text; status={status}]'


def should_retry_skip(text: str) -> bool:
    """Retry ambiguous short ASCII chat that the model may have mistaken for English."""
    t = re.sub(r'[^A-Za-z0-9 ]+', ' ', text).strip().lower()
    words = [w for w in t.split() if w]
    if len(words) < 2:
        return False
    english = {
        'the','this','that','these','those','is','are','was','were','am','i','you','we','they','he','she','it',
        'a','an','and','or','but','to','of','for','in','on','with','from','my','your','our','their','have','has',
        'do','does','did','can','could','will','would','should','make','sure','read','please','thanks','thank','go',
        'come','dark','looking','party','server','wiki','list','limited','event','hello','hey','lol','haha'
    }
    hits = sum(1 for w in words if w in english)
    if hits >= 2:
        return False
    shortish = sum(1 for w in words if 1 <= len(w) <= 6)
    return shortish / max(len(words), 1) >= 0.75


def retry_pinyin(text: str) -> str:
    prompt = """This is definitely intended as informal Chinese gamer Pinyin, possibly abbreviated, typo-filled, or missing spaces. Translate it into concise natural English for FFXI chat. Preserve FFXI names and abbreviations exactly. Keep wo=I/me/my and ni=you/your. Do not output [SKIP]. If a fragment is genuinely unclear, translate only what is supported and do not invent details. Return only English, no notes, no Chinese characters, no quotes."""
    return ask_openai(prompt, text, outgoing=False)


def load_offset() -> int:
    try:
        return int(STATE.read_text(encoding='utf-8').strip())
    except Exception:
        return 0


def save_offset(n: int):
    STATE.write_text(str(n), encoding='utf-8')


def process_line(line: str):
    parts = line.rstrip('\n').split('|', 4)
    if len(parts) != 5:
        return
    id_s, direction, channel, sender, text = parts
    try:
        int(id_s)
    except ValueError:
        return
    text = unesc(text)
    system = SYSTEM_IN if direction == 'IN' else SYSTEM_OUT

    if direction == 'IN':
        key = channel or 'UNKNOWN'
        recent = RECENT_BY_CHANNEL.get(key, [])
        api_text = text
        if recent:
            ctx = '\n'.join(f'- {who}: {msg}' for who, msg in recent[-MAX_CONTEXT:])
            api_text = f'Recent same-channel chat (context only):\n{ctx}\n\nCURRENT message from {sender}:\n{text}'
        translated = ask_openai(system, api_text, outgoing=False)
        if translated == '[SKIP]' and should_retry_skip(text):
            translated = retry_pinyin(text)
        recent.append((sender, text))
        RECENT_BY_CHANNEL[key] = recent[-MAX_CONTEXT:]
    else:
        translated = ask_openai(system, text, outgoing=True)
    with RESP.open('a', encoding='utf-8', newline='') as f:
        f.write(f'{id_s}|{esc(translated)}\n')
    print(f'[{direction} {channel}] {sender}: {text} -> {translated}', flush=True)


def main():
    REQ.touch(exist_ok=True)
    RESP.touch(exist_ok=True)
    offset = load_offset()
    print('LSTranslate bridge running. Leave this window open while playing FFXI.')
    print(f'Model: {MODEL}')
    if not API_KEY:
        print('WARNING: OPENAI_API_KEY is not set. See README.txt.')
    while True:
        try:
            lines = REQ.read_text(encoding='utf-8', errors='replace').splitlines()
            while offset < len(lines):
                process_line(lines[offset])
                offset += 1
                save_offset(offset)
        except Exception as e:
            print('Bridge loop error:', e, flush=True)
        time.sleep(0.25)


if __name__ == '__main__':
    main()
