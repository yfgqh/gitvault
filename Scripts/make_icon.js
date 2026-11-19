// 生成 App 图标：墨黑底 + 紫蓝渐变光环 + 中心封印点（1024x1024 无透明 PNG）
// 用途：CI 与本地都不依赖外部素材，图标随仓库自包含。
const fs = require('fs');
const zlib = require('zlib');
const path = require('path');

const W = 1024, H = 1024;
const px = Buffer.alloc(W * H * 3);

const BASE = [0x0B, 0x0E, 0x14];
const C1 = [0x6E, 0x7B, 0xFF];  // #6E7BFF
const C2 = [0xA6, 0x6C, 0xFF];  // #A66CFF

const mix = (a, b, t) => [
  a[0] + (b[0] - a[0]) * t,
  a[1] + (b[1] - a[1]) * t,
  a[2] + (b[2] - a[2]) * t,
];
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const smooth = (e0, e1, x) => {
  const t = clamp((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
};

for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    const nx = x / W, ny = y / H;

    // 1) 对角渐变光晕
    const d1 = Math.hypot(nx - 0.26, ny - 0.22) / 0.62;
    const d2 = Math.hypot(nx - 0.80, ny - 0.84) / 0.62;
    const glow = clamp(Math.exp(-d1 * d1 * 2.4) * 0.95 + Math.exp(-d2 * d2 * 2.4) * 0.95, 0, 1);

    const diagonal = clamp((nx + ny) / 2, 0, 1);
    let color = mix(BASE, mix(C1, C2, diagonal), glow * 0.92);

    // 2) 中心光环（vault 封印）
    const cx = 0.5, cy = 0.5;
    const dx = nx - cx, dy = ny - cy;
    const r = Math.hypot(dx, dy);
    const ringOuter = 0.315, ringInner = 0.235;
    const ringMask = smooth(ringInner - 0.004, ringInner + 0.006, r) *
                     (1 - smooth(ringOuter - 0.006, ringOuter + 0.004, r));
    if (ringMask > 0) {
      let angle = Math.atan2(dy, dx);
      if (angle < 0) angle += Math.PI * 2;
      const ringColor = mix(C1, C2, (Math.sin(angle) + 1) / 2);
      color = mix(color, ringColor, ringMask);
    }

    // 3) 中心圆点
    const dotMask = 1 - smooth(0.052, 0.060, r);
    if (dotMask > 0) {
      color = mix(color, mix(C1, C2, 0.55), dotMask);
    }

    // 4) 顶部高光，避免整块死黑
    const topLight = clamp(1 - ny / 0.5, 0, 1) * 0.06;
    color = mix(color, [255, 255, 255], topLight);

    const i = (y * W + x) * 3;
    px[i] = Math.round(clamp(color[0], 0, 255));
    px[i + 1] = Math.round(clamp(color[1], 0, 255));
    px[i + 2] = Math.round(clamp(color[2], 0, 255));
  }
}

// --- 最小 PNG 编码器 ---
const crcTable = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

const crc32 = (buf) => {
  let c = 0xFFFFFFFF;
  for (const b of buf) c = crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
};

const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crc]);
};

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(W, 0);
ihdr.writeUInt32BE(H, 4);
ihdr[8] = 8;   // bit depth
ihdr[9] = 2;   // color type: truecolor RGB
ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;

// 每行前置 filter byte 0
const raw = Buffer.alloc(H * (W * 3 + 1));
for (let y = 0; y < H; y++) {
  raw[y * (W * 3 + 1)] = 0;
  px.copy(raw, y * (W * 3 + 1) + 1, y * W * 3, (y + 1) * W * 3);
}

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);

const outDir = path.join(__dirname, '..', 'GitVault', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset');
fs.mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, 'AppIcon.png');
fs.writeFileSync(outPath, png);
console.log('icon written:', outPath, png.length, 'bytes');
