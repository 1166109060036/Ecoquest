// หลายภาษา เฟส 2 (2 พ.ย. 2026) — แอพส่ง Accept-Language: ja|en มาทุก request (lib/services/api_http.dart)
// แปลตอนตอบกลับจุดเดียว (middleware) แทนที่จะแก้ทุก res.json — key = ข้อความอังกฤษตรงตัว เหมือนฝั่งแอพ (lib/l10n/tr.dart)
// key ที่มี {0},{1} = แม่แบบ: จับคู่ข้อความที่ประกอบจากตัวแปร (เช่น `${quest.title} · +${n} points`) แล้วแปลส่วนที่จับได้ซ้ำอีกที
// (ชื่อเควสในข้อความแจ้งเตือนเลยเป็นญี่ปุ่นด้วย) — แจ้งเตือนเก่าใน DB ที่เก็บเป็นอังกฤษก็แปลได้ตอนส่งออก
const ja = require('../i18n/ja');

const DICTS = { ja };

// เฉพาะฟิลด์ที่เป็นข้อความโชว์ผู้ใช้ — ห้ามใส่ฟิลด์ที่แอพส่งกลับมาหรือเอาไปเทียบ (เช่น proofForm.choices, category)
const FIELDS = new Set([
  'message', 'title', 'description', 'detail', 'location', 'label', 'tierLabel',
  'choiceLabel', 'countLabel', 'placeLabel', 'impactCategory', 'city',
]);

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const compile = (dict) =>
  Object.entries(dict)
    .filter(([key]) => /\{\d\}/.test(key) && key.replace(/\{\d\}/g, '').length >= 3)
    .map(([key, value]) => {
      const order = [];
      const source = key
        .split(/(\{\d\})/)
        .map((part) => {
          const m = part.match(/^\{(\d)\}$/);
          if (!m) return escapeRe(part);
          order.push(m[1]);
          return '([\\s\\S]*?)';
        })
        .join('');
      return { re: new RegExp(`^${source}$`), order, value, weight: key.replace(/\{\d\}/g, '').length };
    })
    // แม่แบบที่มีตัวหนังสือคงที่ยาวกว่า = เจาะจงกว่า ลองก่อน
    .sort((a, b) => b.weight - a.weight);

const PATTERNS = Object.fromEntries(Object.entries(DICTS).map(([lang, dict]) => [lang, compile(dict)]));

const langOf = (header) => (/^\s*ja\b/i.test(header || '') ? 'ja' : 'en');

const translateText = (text, lang, depth = 0) => {
  const dict = DICTS[lang];
  if (!dict || typeof text !== 'string' || !text) return text;
  if (Object.prototype.hasOwnProperty.call(dict, text)) return dict[text];
  if (depth > 3) return text;
  for (const p of PATTERNS[lang]) {
    const m = p.re.exec(text);
    if (!m) continue;
    let out = p.value;
    p.order.forEach((idx, i) => {
      out = out.split(`{${idx}}`).join(translateText(m[i + 1], lang, depth + 1));
    });
    return out;
  }
  return text;
};

// แทน t('...', a, b) ตอนประกอบข้อความเอง (อีเมล) — ใช้ key แบบเดียวกับ dict
const t = (lang, key, ...args) =>
  args.reduce((s, a, i) => s.split(`{${i}}`).join(String(a)), DICTS[lang]?.[key] ?? key);

const translateBody = (value, lang, key = null) => {
  if (Array.isArray(value)) return value.map((v) => translateBody(v, lang, key));
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = translateBody(v, lang, k);
    return out;
  }
  return typeof value === 'string' && FIELDS.has(key) ? translateText(value, lang) : value;
};

const i18nMiddleware = (req, res, next) => {
  req.lang = langOf(req.headers['accept-language']);
  if (DICTS[req.lang]) {
    const json = res.json.bind(res);
    // ผ่าน JSON ก่อน — body อาจเป็น mongoose document ที่ walk ตรงๆ ไม่ได้
    res.json = (body) => json(translateBody(JSON.parse(JSON.stringify(body ?? null)), req.lang));
  }
  next();
};

module.exports = { langOf, translateText, t, translateBody, i18nMiddleware, DICTS };
