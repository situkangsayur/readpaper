'use strict';
// DocumentApp tiruan secukupnya untuk menguji Code.js tanpa Google: body
// berisi paragraf, setiap paragraf satu elemen teks berformat per karakter,
// named range yang ikut bergeser saat teks di depannya disisipi atau
// dihapus — perilaku Google Docs yang paling menentukan benar-tidaknya
// sitasi.

const ElementType = { BODY_SECTION: 'BODY_SECTION', PARAGRAPH: 'PARAGRAPH', TEXT: 'TEXT', LIST_ITEM: 'LIST_ITEM' };
const TextAlignment = { NORMAL: 'NORMAL', SUPERSCRIPT: 'SUPERSCRIPT', SUBSCRIPT: 'SUBSCRIPT' };

function makeDoc() {
  let nextId = 1;
  const ranges = []; // {id, name, parts: [{el, start, end}] | [{para}]}
  let cursor = null;

  class Text {
    constructor(para, s) { this.para = para; this.s = s; this.attrs = [...s].map(() => ({})); }
    getType() { return ElementType.TEXT; }
    getParent() { return this.para; }
    getText() { return this.s; }
    asText() { return this; }
    insertText(off, str) {
      this.s = this.s.slice(0, off) + str + this.s.slice(off);
      this.attrs.splice(off, 0, ...[...str].map(() => ({})));
      ranges.forEach((r) => r.parts.forEach((p) => {
        if (p.el !== this) return;
        // Seperti Google Docs: sisipan di dalam atau tepat di ujung kanan
        // rentang tidak memperluasnya ke kanan; sisipan di kiri menggesernya.
        if (off <= p.start) { p.start += str.length; p.end += str.length; } else if (off <= p.end) p.end += str.length;
      }));
      if (cursor && cursor.el === this && cursor.off >= off) cursor.off += str.length;
      return this;
    }
    deleteText(a, b) {
      const n = b - a + 1;
      this.s = this.s.slice(0, a) + this.s.slice(b + 1);
      this.attrs.splice(a, n);
      ranges.forEach((r) => {
        r.parts = r.parts.filter((p) => {
          if (p.el !== this) return true;
          if (p.end < a) return true;
          if (p.start > b) { p.start -= n; p.end -= n; return true; }
          const ns = p.start < a ? p.start : a;
          const ne = p.end > b ? p.end - n : a - 1;
          if (ne < ns) return false; // seluruh rentang terhapus
          p.start = ns; p.end = ne; return true;
        });
      });
      return this;
    }
    _set(a, b, k, v) { for (let i = a; i <= b; i++) this.attrs[i][k] = v; return this; }
    setItalic(a, b, v) { return this._set(a, b, 'italic', v); }
    setBold(a, b, v) { return this._set(a, b, 'bold', v); }
    setUnderline(a, b, v) { return this._set(a, b, 'underline', v); }
    setTextAlignment(a, b, v) { return this._set(a, b, 'align', v); }
  }

  class Paragraph {
    constructor(body, s) { this.body = body; this.text = new Text(this, s); this.props = {}; }
    getType() { return ElementType.PARAGRAPH; }
    getParent() { return this.body; }
    getChildIndex(el) { return el === this.text ? 0 : -1; }
    getText() { return this.text.s; }
    editAsText() { return this.text; }
    appendText(s) { this.text.insertText(this.text.s.length, s); return this.text; }
    setIndentStart(v) { this.props.indentStart = v; return this; }
    setIndentFirstLine(v) { this.props.indentFirstLine = v; return this; }
    setLineSpacing(v) { this.props.lineSpacing = v; return this; }
    setSpacingAfter(v) { this.props.spacingAfter = v; return this; }
    removeFromParent() {
      const i = this.body.children.indexOf(this);
      if (i === this.body.children.length - 1) throw new Error('Paragraf terakhir body tidak boleh dihapus.');
      this.body.children.splice(i, 1);
      ranges.forEach((r) => { r.parts = r.parts.filter((p) => p.para !== this && p.el !== this.text); });
    }
  }

  class Body {
    constructor() { this.children = [new Paragraph(this, '')]; }
    getType() { return ElementType.BODY_SECTION; }
    getParent() { return null; }
    getChildIndex(el) { return this.children.indexOf(el); }
    getNumChildren() { return this.children.length; }
    insertParagraph(i, s) { const p = new Paragraph(this, s); this.children.splice(i, 0, p); return p; }
    appendParagraph(s) { const p = new Paragraph(this, s); this.children.push(p); return p; }
  }

  const body = new Body();

  function rangeElements(r) {
    return r.parts.map((p) => p.para ? {
      getElement: () => p.para, isPartial: () => false,
      getStartOffset: () => -1, getEndOffsetInclusive: () => -1,
    } : {
      getElement: () => p.el, isPartial: () => true,
      getStartOffset: () => p.start, getEndOffsetInclusive: () => p.end,
    });
  }

  function named(r) {
    return {
      getId: () => r.id, getName: () => r.name,
      getRange: () => ({ getRangeElements: () => rangeElements(r) }),
      remove: () => { const i = ranges.indexOf(r); if (i >= 0) ranges.splice(i, 1); },
    };
  }

  const doc = {
    getBody: () => body,
    newRange() {
      const parts = [];
      const b = {
        addElement(el, start, end) {
          if (el instanceof Text) parts.push({ el, start, end });
          else parts.push({ para: el });
          return b;
        },
        build: () => ({ parts }),
      };
      return b;
    },
    addNamedRange(name, range) {
      const r = { id: 'kix.' + nextId++, name, parts: range.parts.map((p) => Object.assign({}, p)) };
      ranges.push(r);
      return named(r);
    },
    getNamedRanges(name) { return ranges.filter((r) => !name || r.name === name).map(named); },
    newPosition: (el, off) => ({ el, off }),
    setCursor(pos) { cursor = { el: pos.el, off: pos.off }; },
    getSelection: () => null,
    getCursor() {
      if (!cursor) return null;
      const c = cursor;
      return {
        getSurroundingText: () => c.el,
        getSurroundingTextOffset: () => c.off,
        getElement: () => c.el,
        getOffset: () => c.off,
      };
    },
  };

  // Bantuan uji: mengetik di akhir paragraf terakhir, pindah kursor, isi teks.
  const helpers = {
    type(s) {
      const last = body.children[body.children.length - 1].text;
      last.insertText(last.s.length, s);
      cursor = { el: last, off: last.s.length };
    },
    newParagraph() { body.appendParagraph(''); const t = body.children[body.children.length - 1].text; cursor = { el: t, off: 0 }; },
    cursorAt(el, off) { cursor = { el, off }; },
    text: () => body.children.map((p) => p.text.s).join('\n'),
    body, ranges,
  };
  return { doc, helpers };
}

function makeGlobals(doc) {
  const store = new Map();
  return {
    DocumentApp: { ElementType, TextAlignment, getActiveDocument: () => doc, getUi: () => ({}) },
    PropertiesService: {
      getDocumentProperties: () => ({
        getProperty: (k) => (store.has(k) ? store.get(k) : null),
        setProperties: (o) => Object.keys(o).forEach((k) => store.set(k, String(o[k]))),
        deleteProperty: (k) => store.delete(k),
      }),
    },
    HtmlService: {},
    _props: store,
  };
}

module.exports = { makeDoc, makeGlobals };
