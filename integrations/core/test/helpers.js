'use strict';
// Gaya dan locale asli dari assets/csl/, persis yang dikirim server.
const fs = require('fs');
const path = require('path');
const RP = require('../citations.js');

const CSL_DIR = path.join(__dirname, '..', '..', '..', 'assets', 'csl');

/** XML gaya; gaya dependen diganti induknya, seperti GET /api/styles/<id>. */
function styleXml(id) {
  const xml = fs.readFileSync(path.join(CSL_DIR, 'styles', id + '.csl'), 'utf8');
  const parent = /<link\s+href="[^"]*\/([^"/]+)"\s+rel="independent-parent"/.exec(xml);
  return parent ? styleXml(parent[1]) : xml;
}

function localeXml(tag) {
  const p = path.join(CSL_DIR, 'locales', 'locales-' + tag + '.xml');
  return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
}

function processor(styleId, locale) {
  return new RP.CitationProcessor({
    styleXml: styleXml(styleId),
    locale: locale || 'id-ID',
    retrieveLocale: (tag) => localeXml(tag) || localeXml('en-US'),
  });
}

// Item CSL-JSON seperti keluaran CslJson.of di ReadPaper.
const ITEMS = {
  MCCLEAN: {
    id: 'MCCLEAN', type: 'article-journal',
    title: 'Barren plateaus in quantum neural network training landscapes',
    author: [
      { family: 'McClean', given: 'Jarrod R.' }, { family: 'Boixo', given: 'Sergio' },
      { family: 'Smelyanskiy', given: 'Vadim N.' }, { family: 'Babbush', given: 'Ryan' },
      { family: 'Neven', given: 'Hartmut' },
    ],
    'container-title': 'Nature Communications', volume: '9', page: '4812',
    issued: { 'date-parts': [[2018]] }, DOI: '10.1038/s41467-018-07090-4',
  },
  KARISMA: {
    id: 'KARISMA', type: 'book', title: 'Membaca makalah dengan tenang',
    author: [{ family: 'Karisma', given: 'Hendri' }],
    publisher: 'Penerbit Contoh', 'publisher-place': 'Bandung',
    issued: { 'date-parts': [[2020]] },
  },
  ZHANG: {
    id: 'ZHANG', type: 'article-journal', title: 'Alpha study of things',
    author: [{ family: 'Zhang', given: 'Wei' }, { family: 'Abbott', given: 'Lee' }],
    'container-title': 'Journal of Examples', volume: '3', issue: '2', page: '10-20',
    issued: { 'date-parts': [[2015]] },
  },
  ADAMS: {
    id: 'ADAMS', type: 'article-journal', title: 'Uncited but listed',
    author: [{ family: 'Adams', given: 'Ann' }],
    'container-title': 'Journal of Examples', issued: { 'date-parts': [[2010]] },
  },
};

function cite(keys, opts) {
  opts = opts || {};
  const list = Array.isArray(keys) ? keys : [keys];
  return RP.makeCitation(list.map((k) => Object.assign({ itemData: ITEMS[k], key: k }, (opts.item || {})[k] || {})), opts);
}

module.exports = { RP, styleXml, localeXml, processor, ITEMS, cite, CSL_DIR };
