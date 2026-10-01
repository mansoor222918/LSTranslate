addon.name = 'LSTranslate';
addon.author = 'OpenAI + Harambe';
addon.version = '1.5.0';
addon.desc = 'Safe smart chat translator for Tell / Linkshell / Party.';
addon.link = '';

require 'common';
local chat = require 'chat';

local ROOT = ('%s\\addons\\LSTranslate\\'):fmt(AshitaCore:GetInstallPath());
local REQ  = ROOT .. 'requests.txt';
local RESP = ROOT .. 'responses.txt';

local state = {
    next_id = 1,
    seen_resp = 0,
    debug = false,
    last_tell = nil,
    last_channel = nil,
    pending = {},
};

local MODE = {
    [0x03] = 'TELL',
    [0x04] = 'PARTY',
    [0x05] = 'LS',
    [0x0D] = 'LS2',
};

local function esc(s)
    s = tostring(s or '');
    s = s:gsub('%%', '%%25');
    s = s:gsub('|', '%%7C');
    s = s:gsub('\r', '%%0D');
    s = s:gsub('\n', '%%0A');
    return s;
end

local function unesc(s)
    s = tostring(s or '');
    s = s:gsub('%%0A', '\n');
    s = s:gsub('%%0D', '\r');
    s = s:gsub('%%7C', '|');
    s = s:gsub('%%25', '%%');
    return s;
end

local function trim0(s)
    return (s or ''):gsub('%z+$', ''):gsub('^%s+', ''):gsub('%s+$', '');
end

local function append_line(path, line)
    local f = io.open(path, 'a');
    if not f then return false; end
    f:write(line, '\n');
    f:close();
    return true;
end

local function enqueue(direction, channel, sender, text, send_mode, send_target)
    local id = state.next_id;
    state.next_id = state.next_id + 1;
    state.pending[id] = {
        direction = direction,
        channel = channel,
        sender = sender,
        send_mode = send_mode,
        send_target = send_target,
        original = text,
    };
    local ok = append_line(REQ, ('%d|%s|%s|%s|%s'):fmt(id, direction, esc(channel), esc(sender), esc(text)));
    if not ok then
        print(chat.header('LSTranslate'):append(chat.error('Could not write requests.txt.')));
    end
end

local ENGLISH_WORDS = {
    ['the']=true,['this']=true,['that']=true,['these']=true,['those']=true,['is']=true,['are']=true,['was']=true,['were']=true,
    ['i']=true,['you']=true,['we']=true,['they']=true,['he']=true,['she']=true,['it']=true,['a']=true,['an']=true,['and']=true,
    ['or']=true,['but']=true,['to']=true,['of']=true,['for']=true,['in']=true,['on']=true,['with']=true,['from']=true,['my']=true,
    ['your']=true,['our']=true,['their']=true,['have']=true,['has']=true,['had']=true,['do']=true,['does']=true,['did']=true,
    ['can']=true,['could']=true,['will']=true,['would']=true,['should']=true,['just']=true,['use']=true,['make']=true,['sure']=true,
    ['read']=true,['please']=true,['thanks']=true,['thank']=true,['go']=true,['come']=true,['coming']=true,['dark']=true,
    ['looking']=true,['party']=true,['server']=true,['wiki']=true,['list']=true,['limited']=true,['event']=true,['hello']=true,
    ['hey']=true,['yes']=true,['no']=true,['not']=true,['now']=true,['later']=true,['tomorrow']=true,['today']=true,['need']=true,
    ['want']=true,['know']=true,['good']=true,['bad']=true,['nice']=true,['ok']=true,['okay']=true,['lol']=true,['haha']=true,
    ['weapon']=true,['gear']=true,['item']=true,['items']=true,['drop']=true,['drops']=true,['farm']=true,['kill']=true,['boss']=true,
    ['sex']=true,['thing']=true,['things']=true,['griff']=true,['job']=true,['jobs']=true,['able']=true,['anyone']=true,
    ['bring']=true,['all']=true,['back']=true,['keep']=true,['alive']=true,['sounds']=true,['like']=true,['time']=true,['much']=true,
    ['long']=true,['busy']=true,['before']=true,['after']=true,['ready']=true,['stop']=true,['one']=true,['two']=true,
};

local PINYIN_WORDS = {
    ['wo']=true,['ni']=true,['nin']=true,['ta']=true,['women']=true,['nimen']=true,['tamen']=true,['shi']=true,['bu']=true,
    ['mei']=true,['you']=true,['yao']=true,['xiang']=true,['hui']=true,['neng']=true,['keyi']=true,['ke']=true,['yi']=true,
    ['ge']=true,['zhe']=true,['na']=true,['zenme']=true,['zm']=true,['shenme']=true,['sm']=true,['weishenme']=true,['zai']=true,
    ['le']=true,['la']=true,['ma']=true,['ba']=true,['a']=true,['de']=true,['di']=true,['hen']=true,['tai']=true,['zhen']=true,
    ['dou']=true,['hai']=true,['ye']=true,['jiu']=true,['gen']=true,['he']=true,['gei']=true,['bang']=true,['xie']=true,
    ['xiexie']=true,['hao']=true,['haode']=true,['bie']=true,['danxin']=true,['ren']=true,['renshi']=true,['jia']=true,
    ['ru']=true,['lai']=true,['qu']=true,['zou']=true,['cuo']=true,['lu']=true,['kan']=true,['shuo']=true,['hua']=true,
    ['liaotian']=true,['zhidao']=true,['zhi']=true,['dao']=true,['sha']=true,['lihai']=true,['li']=true,['hai']=true,
    ['pinyin']=true,['pin']=true,['yin']=true,['pi']=true,['gu']=true,['da']=true,['xiao']=true,['duo']=true,['shao']=true,
    ['wan']=true,['mingtian']=true,['xianzai']=true,['yixia']=true,['diao']=true,['za']=true,['cao']=true,['gan']=true,
    ['fangbian']=true,['zhuangbei']=true,['zhuang']=true,['bei']=true,['qian']=true,['mai']=true,['huan']=true,['ka']=true,
    ['shijian']=true,['zhongguo']=true,['taiwan']=true,['xiongdi']=true,['dage']=true,['lao']=true,['fan']=true,['yue']=true,
    ['zuijin']=true,['mang']=true,['chang']=true,['xz']=true,['deng']=true,['dian']=true,['qing']=true,['long']=true,
    ['bai']=true,['hu']=true,['genbu']=true,['xuanwu']=true,['yige']=true,['yihui']=true,['tian']=true,['kong']=true,
    ['pao']=true,['guo']=true,['xia']=true,['zhuangtai']=true,['bijiao']=true,['buxing']=true,['chulai']=true,
    ['chu']=true,['nei']=true,['keng']=true,['chi']=true,['zhuan']=true,['zheyang']=true,['bijiang']=true,
    ['zao']=true,['shihou']=true,['jixu']=true,['zuzhi']=true,['zuzhu']=true,['huozhe']=true,['kuai']=true,['zheme']=true,
    ['guanxi']=true,['mingbai']=true,['pengyou']=true,['yingyu']=true,['youxiu']=true,['wanjia']=true,['xinren']=true,['xuyao']=true,
    ['shui']=true,['jiao']=true,['yong']=true,['kai']=true,['sp']=true,['ting']=true,['mianzi']=true,['gangcai']=true,['shang']=true,
};

local STRONG_PINYIN = {
    ['wo']=true,['ni']=true,['nin']=true,['ta']=true,['women']=true,['nimen']=true,['tamen']=true,['bu']=true,['mei']=true,
    ['yao']=true,['xiang']=true,['hui']=true,['neng']=true,['keyi']=true,['zenme']=true,['zm']=true,['shenme']=true,['sm']=true,
    ['weishenme']=true,['zai']=true,['bie']=true,['xiexie']=true,['danxin']=true,['renshi']=true,['liaotian']=true,
    ['zhidao']=true,['lihai']=true,['pinyin']=true,['xianzai']=true,['mingtian']=true,['fangbian']=true,['zhuangbei']=true,
    ['zhongguo']=true,['taiwan']=true,['xiongdi']=true,['dage']=true,['zuijin']=true,['yihui']=true,['zhuangtai']=true,
    ['qing']=true,['genbu']=true,['xuanwu']=true,['chulai']=true,['zheyang']=true,['bijiang']=true,
    ['zao']=true,['shihou']=true,['jixu']=true,['huozhe']=true,['zheme']=true,['kuai']=true,['xuyao']=true,['shui']=true,['yong']=true,
};

local SHORT_PINYIN_SAFE = {
    ['lai']=true,['zou']=true,['hao']=true,['haode']=true,['dui']=true,['en']=true,['da']=true,['mei']=true,
    ['yao']=true,['bie']=true,['deng']=true,['dian']=true,['chi']=true,['cao']=true,['xiexie']=true,['zao']=true,['dui']=true,['en']=true,
};

local FFXI_OR_NAMES = {
    ['ls']=true,['nm']=true,['ki']=true,['tod']=true,['dc']=true,['aby']=true,['abyssea']=true,['flux']=true,['tomahawk']=true,
    ['sp']=true,['dkp']=true,['dpk']=true,['brew']=true,['nyx']=true,['byakko']=true,['attohwa']=true,['chasm']=true,['summit']=true,
    ['pld']=true,['whm']=true,['blm']=true,['rdm']=true,['thf']=true,['war']=true,['mnk']=true,['nin']=true,['sam']=true,['drk']=true,['drg']=true,['rng']=true,['brd']=true,['bst']=true,['smn']=true,['blu']=true,['cor']=true,['pup']=true,['sch']=true,['dnc']=true,['run']=true,['geo']=true,
    ['kennan']=true,['dodo']=true,['laowang']=true,['qjutian']=true,['qiutian']=true,['yaoji']=true,['shambe']=true,['huli']=true,
};

local function has_cjk(s)
    s = tostring(s or '');
    local n = #s;
    local i = 1;
    while i <= n - 2 do
        local b1, b2, b3 = s:byte(i, i + 2);
        if b1 and b2 and b3 and b1 >= 0xE4 and b1 <= 0xE9
            and b2 >= 0x80 and b2 <= 0xBF
            and b3 >= 0x80 and b3 <= 0xBF then
            return true;
        end
        i = i + 1;
    end
    return false;
end

local function looks_like_translation_candidate(s, channel)
    if not s or #s < 1 then return false; end
    if has_cjk(s) then return true; end

    local words = {};
    for w in s:lower():gmatch("[%a']+") do
        words[#words + 1] = w;
    end
    if #words == 0 then return false; end

    -- Single-word chat is kept conservative so normal English like "ready" or
    -- "back" never creates API noise. Known short Pinyin (including zao) passes.
    if #words == 1 then
        return SHORT_PINYIN_SAFE[words[1]] == true;
    end

    local en, py, strong_py = 0, 0, 0;
    for _, w in ipairs(words) do
        if STRONG_PINYIN[w] then strong_py = strong_py + 1; end
        if PINYIN_WORDS[w] then py = py + 1; end
        if ENGLISH_WORDS[w] then en = en + 1; end
    end

    -- v1.5: only reject messages that are clearly ordinary English. Everything
    -- else from Tell/Party/LS is allowed to reach the bridge, where the model
    -- makes the final Pinyin-vs-English decision and can return [SKIP].
    if strong_py >= 1 or py >= 2 then return true; end
    if en >= 2 and en >= math.ceil(#words * 0.50) then return false; end
    if en >= 3 then return false; end

    -- Gamer Pinyin is often typo-filled/abbreviated and mixed with FFXI terms.
    -- Passing uncertain multi-word lines fixes the "sometimes it translates"
    -- problem without ever sending chat back to the server.
    return true;
end

local function queue_chat_command(cmd, success_text)
    cmd = tostring(cmd or ''):gsub('[\r\n]+', ' '):gsub('^%s+', ''):gsub('%s+$', '');
    if cmd == '' then
        print(chat.header('LSTranslate'):append(chat.error('Nothing to send.')));
        return;
    end

    -- Route through Ashita's command layer (-1). This is still one user-requested
    -- chat command, but is more reliable than injecting it directly while polling.
    local ok, err = pcall(function ()
        AshitaCore:GetChatManager():QueueCommand(1, cmd);
    end);

    if ok then
        print(chat.header('LSTranslate'):append(chat.success(success_text)));
    else
        print(chat.header('LSTranslate'):append(chat.error('Send failed: ' .. tostring(err))));
    end
end

local function send_translated(p, translated)
    translated = tostring(translated or ''):gsub('[\r\n]+', ' '):gsub('^%s+', ''):gsub('%s+$', '');
    if translated == '' then
        print(chat.header('LSTranslate'):append(chat.error('Translation was empty; nothing sent.')));
        return;
    end

    if p.send_mode == 'tell' and p.send_target and p.send_target ~= '' then
        queue_chat_command(('/tell %s %s'):fmt(p.send_target, translated), ('Sent tell to %s.'):fmt(p.send_target));
    elseif p.send_mode == 'ls' then
        queue_chat_command(('/linkshell %s'):fmt(translated), 'Sent to linkshell.');
    elseif p.send_mode == 'party' then
        queue_chat_command(('/party %s'):fmt(translated), 'Sent to party.');
    end
end

local function poll_responses()
    local f = io.open(RESP, 'r');
    if not f then return; end
    local i = 0;
    for line in f:lines() do
        i = i + 1;
        if i > state.seen_resp then
            local id_s, body = line:match('^(%d+)|(.+)$');
            local id = tonumber(id_s or '');
            if id and body then
                local p = state.pending[id];
                local translated = unesc(body);
                if p then
                    if p.direction == 'IN' then
                        local upper = translated:upper();
                        local is_silent = (upper == '[SKIP]' or upper == '[SILENT]');
                        local is_error = translated:lower():match('^%[bridge') ~= nil;
                        if not is_silent and not is_error and translated ~= '' then
                            local label = ('[%s] %s'):fmt(p.channel or '?', p.sender or '?');
                            print(chat.header('LSTranslate'):append(chat.message(label .. ' -> ')):append(chat.success(translated)));
                        elseif is_error and state.debug then
                            print(chat.header('LSTranslate'):append(chat.error(translated)));
                        end
                    else
                        local upper = translated:upper();
                        local is_silent = (upper == '[SKIP]' or upper == '[SILENT]');
                        local is_error = translated:lower():match('^%[bridge') ~= nil;
                        if is_silent or is_error or translated == '' then
                            print(chat.header('LSTranslate'):append(chat.error('Translation failed; nothing was sent.')));
                        else
                            print(chat.header('LSTranslate'):append(chat.message('Pinyin: ')):append(chat.success(translated)));
                            send_translated(p, translated);
                        end
                    end
                    state.pending[id] = nil;
                end
            end
        end
    end
    f:close();
    state.seen_resp = i;
end

local function command_text_after(raw, nspaces)
    local pos = 1;
    for _ = 1, nspaces do
        local p = raw:find(' ', pos, true);
        if not p then return ''; end
        pos = p + 1;
    end
    return raw:sub(pos);
end

ashita.events.register('load', 'lst_load', function ()
    -- Touch queue files so the Python bridge can find them.
    local f = io.open(REQ, 'a'); if f then f:close(); end
    f = io.open(RESP, 'a'); if f then f:close(); end
    print(chat.header('LSTranslate'):append(chat.success('Loaded. Tell / LS1 / LS2 / Party smart translation enabled.')));
    print(chat.header('LSTranslate'):append(chat.message('Use /lt help for reply commands.')));
end);

local function get_own_name()
    local ok, name = pcall(function ()
        return AshitaCore:GetMemoryManager():GetParty():GetMemberName(0);
    end);
    if ok and name then return trim0(name); end
    return '';
end

-- Read-only packet parser: never modifies or injects incoming packets.
ashita.events.register('packet_in', 'lst_packet_in', function (e)
    if e.id ~= 0x0017 then return; end

    local mode = struct.unpack('B', e.data_modified, 0x04 + 1);
    local channel = MODE[mode];
    if not channel then
        if state.debug then
            print(chat.header('LSTranslate'):append(chat.message(('Chat packet mode: 0x%02X'):fmt(mode))));
        end
        return;
    end

    local sender = trim0(struct.unpack('c15', e.data_modified, 0x08 + 1));
    local msg = trim0(e.data_modified:sub(0x18 + 1));
    msg = AshitaCore:GetChatManager():ParseAutoTranslate(msg, true);
    msg = msg:strip_colors():strip_translate(true);

    if sender == '' or msg == '' then return; end

    -- Avoid translating our own Party / LS echo after /lt sends a Pinyin line.
    local own_name = get_own_name();
    if own_name ~= '' and sender:lower() == own_name:lower() then return; end

    if channel == 'TELL' then
        state.last_tell = sender;
    end
    state.last_channel = channel;

    if looks_like_translation_candidate(msg, channel) then
        enqueue('IN', channel, sender, msg, nil, nil);
    end
end);

ashita.events.register('d3d_present', 'lst_poll', function ()
    poll_responses();
end);

ashita.events.register('command', 'lst_command', function (e)
    local raw = tostring(e.command or '');
    local lower = raw:lower();

    -- Only handle /lt and /lst commands. Parse the raw command string directly
    -- so subcommands are reliable across Ashita string helper behavior.
    if not (lower:match('^/lt%s*') or lower:match('^/lst%s*')) then return; end
    e.blocked = true;

    local rest = raw:match('^/%S+%s*(.*)$') or '';
    local rest_lower = rest:lower();

    if rest == '' or rest_lower == 'help' or rest_lower == '?' then
        print(chat.header('LSTranslate'):append(chat.message('Commands:')));
        print(chat.message('/lt <English>              - translate to simple Pinyin (preview only)'));
        print(chat.message('/lt t <Name> <English>     - translate + send ONE tell'));
        print(chat.message('/lt r <English>            - translate + send ONE tell to last teller'));
        print(chat.message('/lt l <English>            - translate + send ONE LS message'));
        print(chat.message('/lt p <English>            - translate + send ONE party message'));
        print(chat.message('/lt debug                   - show unknown incoming chat modes'));
        return;
    end

    if rest_lower == 'debug' then
        state.debug = not state.debug;
        print(chat.header('LSTranslate'):append(chat.message('Debug: ')):append(chat.success(state.debug and 'ON' or 'OFF')));
        return;
    end

    local target, text = rest:match('^[tT]%s+(%S+)%s+(.+)$');
    if target and text then
        enqueue('OUT', 'TELL', target, text, 'tell', target);
        return;
    end

    text = rest:match('^[rR]%s+(.+)$');
    if text then
        if not state.last_tell then
            print(chat.header('LSTranslate'):append(chat.error('No last teller recorded yet.')));
            return;
        end
        enqueue('OUT', 'TELL', state.last_tell, text, 'tell', state.last_tell);
        return;
    end

    text = rest:match('^[lL]%s+(.+)$');
    if text then
        enqueue('OUT', 'LS', '', text, 'ls', nil);
        return;
    end

    text = rest:match('^[pP]%s+(.+)$');
    if text then
        enqueue('OUT', 'PARTY', '', text, 'party', nil);
        return;
    end

    -- If the user started a send subcommand but the syntax is incomplete,
    -- show an error instead of silently treating it as preview text.
    if rest_lower:match('^[trpl]%s') or rest_lower:any('t','r','p','l') then
        print(chat.header('LSTranslate'):append(chat.error('Invalid send syntax. Use /lt help.')));
        return;
    end

    enqueue('OUT', 'PREVIEW', '', rest, nil, nil);
end);
