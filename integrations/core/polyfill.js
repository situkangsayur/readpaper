/*
 * Yang dipakai inti sitasi dari peramban tetapi tidak ada di mesin
 * JavaScript polos (QuickJS di dalam ReadPaper): TextEncoder/TextDecoder
 * UTF-8, btoa/atob, dan setTimeout yang tidak pernah berbunyi.
 *
 * Hanya dimuat oleh host di ReadPaper, sebelum berkas inti lainnya. Panel
 * Word, OnlyOffice, dan Google Docs berjalan di peramban dan tidak memuatnya.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (g) {
  'use strict';

  if (typeof g.TextEncoder === 'undefined') {
    g.TextEncoder = function TextEncoder() {};
    g.TextEncoder.prototype.encode = function (s) {
      s = String(s);
      var out = [];
      for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
          var d = s.charCodeAt(i + 1);
          if (d >= 0xdc00 && d <= 0xdfff) {
            c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00);
            i++;
          }
        }
        if (c < 0x80) out.push(c);
        else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63));
        else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
        else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      }
      return new Uint8Array(out);
    };
  }

  if (typeof g.TextDecoder === 'undefined') {
    g.TextDecoder = function TextDecoder() {};
    g.TextDecoder.prototype.decode = function (bytes) {
      var b = bytes || [];
      var parts = [];
      var chunk = [];
      for (var i = 0; i < b.length;) {
        var c = b[i++];
        var cp;
        if (c < 0x80) cp = c;
        else if (c >= 0xf0) { cp = ((c & 7) << 18) | ((b[i++] & 63) << 12) | ((b[i++] & 63) << 6) | (b[i++] & 63); }
        else if (c >= 0xe0) { cp = ((c & 15) << 12) | ((b[i++] & 63) << 6) | (b[i++] & 63); }
        else { cp = ((c & 31) << 6) | (b[i++] & 63); }
        if (cp > 0xffff) {
          cp -= 0x10000;
          chunk.push(0xd800 + (cp >> 10), 0xdc00 + (cp & 1023));
        } else {
          chunk.push(cp);
        }
        if (chunk.length > 4096) { parts.push(String.fromCharCode.apply(null, chunk)); chunk = []; }
      }
      parts.push(String.fromCharCode.apply(null, chunk));
      return parts.join('');
    };
  }

  var B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  if (typeof g.btoa === 'undefined') {
    g.btoa = function (bin) {
      bin = String(bin);
      var out = [];
      for (var i = 0; i < bin.length; i += 3) {
        var a = bin.charCodeAt(i);
        var b = i + 1 < bin.length ? bin.charCodeAt(i + 1) : NaN;
        var c = i + 2 < bin.length ? bin.charCodeAt(i + 2) : NaN;
        var n = (a << 16) | ((b || 0) << 8) | (c || 0);
        out.push(B64[(n >> 18) & 63], B64[(n >> 12) & 63],
          isNaN(b) ? '=' : B64[(n >> 6) & 63], isNaN(c) ? '=' : B64[n & 63]);
      }
      return out.join('');
    };
  }

  if (typeof g.atob === 'undefined') {
    g.atob = function (s) {
      s = String(s).replace(/[^A-Za-z0-9+/]/g, '');
      var out = [];
      for (var i = 0; i < s.length; i += 4) {
        var n = (B64.indexOf(s[i]) << 18) | (B64.indexOf(s[i + 1]) << 12) |
          ((i + 2 < s.length ? B64.indexOf(s[i + 2]) : 0) << 6) | (i + 3 < s.length ? B64.indexOf(s[i + 3]) : 0);
        out.push(String.fromCharCode((n >> 16) & 255));
        if (i + 2 < s.length) out.push(String.fromCharCode((n >> 8) & 255));
        if (i + 3 < s.length) out.push(String.fromCharCode(n & 255));
      }
      return out.join('');
    };
  }

  // Satu perintah selesai dalam satu putaran antrean job, jadi batas waktu
  // ReadPaperApi tidak pernah perlu berbunyi.
  g.setTimeout = function () { return 0; };
  g.clearTimeout = function () {};
})(typeof globalThis !== 'undefined' ? globalThis : this);
