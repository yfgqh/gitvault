// GitVault 图标 v2：借鉴 GitHub（Octocat 猫耳 + fork 分支语义），做「GitVault 保险库」二次创新。
// 构成：猫耳圆环（vault 转盘 + Octocat 致敬）+ 中心 fork 三节点（GitHub 语言）+ 墨黑底 + 紫蓝渐变。
// 纯 Node 生成 1024x1024 无透明 PNG，不依赖任何图像库。
const fs = require('fs');
const zlib = require('zlib');
const path = require('path');

const S = 1024;
const px = new Float32Array(S * S * 3);

const hex = (h) => [(h >> 16) & 255, (h >> 8) & 255, h & 255];
const C_BG0 = hex(0x0b0e14);   // 墨黑
const C_BG1 = hex(0x141a2b);   // 深蓝黑
const C_A = hex(0x6e7bff);     // 品牌蓝紫
const C_B = hex(0xa66cff);     // 品牌紫
const C_WHITE = [255, 255, 255];

const clamp01 = (v) => Math.min(1, Math.max(0, v));
const smooth = (e0, e1, x) => {
  const t = clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
};
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const L = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

// 线段 SDF（含圆头）
function segDist(p, a, b) {
  const ab = [b[0] - a[0], b[1] - a[1]];
  const ap = [p[0] - a[0], p[1] - a[1]];
  const denom = ab[0] * ab[0] + ab[1] * ab[1] || 1;
  const t = clamp01((ap[0] * ab[0] + ap[1] * ab[1]) / denom);
  const proj = [a[0] + ab[0] * t, a[1] + ab[1] * t];
  return L(p, proj);
}

// 猫耳：在基准角 θe 附近的角窗口内，把外扩量做成余弦凸起（Octocat 的耳朵语言）
const RING_R = 0.322;
const RING_T = 0.052;
const EAR_ANGLES = [-2.55, -0.59];   // 约 10:30 与 1:30 方向（弧度）
const EAR_HALF = 0.30;
const EAR_LIFT = 0.070;

function ringRadius(theta) {
  let r = RING_R;
  for (const e of EAR_ANGLES) {
    let d = Math.atan2(Math.sin(theta - e), Math.cos(theta - e));
    if (Math.abs(d) < EAR_HALF) {
      r += EAR_LIFT * Math.cos((d / EAR_HALF) * Math.PI * 0.5);
    }
  }
  return r;
}

// fork 符号几何（归一化坐标，中心 0,0）
const A = [0.0, -0.112];      // 顶端节点
const FORK = [0.0, 0.010];    // 分叉点
const B = [-0.110, 0.116];    // 左下节点
const C = [0.110, 0.116];     // 右下节点
const NODE_R = 0.049;
const STEM_W = 0.020;

const aa = 1.6 / S; // 抗锯齿带宽

for (let y = 0; y < S; y++) {
  for (let x = 0; x < S; x++) {
    const u = x / S, v = y / S;
    const p = [u, v];
    const dx = u - 0.5, dy = v - 0.5;
    const r = Math.hypot(dx, dy);
    const theta = Math.atan2(dy, dx);

    // 1) 背景：径向渐变 + 左上紫色辉光
    let bg = mix(C_BG0, C_BG1, clamp01(r / 0.72));
    const glow = Math.exp(-((Math.hypot(u - 0.26, v - 0.20) / 0.46) ** 2) * 2.2);
    bg = mix(bg, C_A, glow * 0.30);

    let color = bg;

    // 2) 猫耳圆环
    const rr = ringRadius(theta);
    const ringD = Math.abs(r - rr) - RING_T / 2;
    const ringMask = 1 - smooth(-aa, aa, ringD);
    if (ringMask > 0) {
      // 环上角度渐变色（左下蓝 → 右上紫）
      const t = clamp01((Math.sin(theta - 2.2) + 1) / 2 * 0.78 + v * 0.22);
      const ringColor = mix(C_A, C_B, t);
      color = mix(color, ringColor, ringMask);
      const halo = (1 - smooth(-0.02, 0.06, ringD)) * 0.18;
      color = mix(color, ringColor, halo);
    }

    // 4) fork 符号（白色）：三节点 + 两段连线
    let symD = Infinity;
    symD = Math.min(symD, L(p, [0.5 + A[0], 0.5 + A[1]]) - NODE_R);
    symD = Math.min(symD, L(p, [0.5 + B[0], 0.5 + B[1]]) - NODE_R);
    symD = Math.min(symD, L(p, [0.5 + C[0], 0.5 + C[1]]) - NODE_R);

    const aW = [0.5 + A[0], 0.5 + A[1]];
    const fW = [0.5 + FORK[0], 0.5 + FORK[1]];
    const bW = [0.5 + B[0], 0.5 + B[1]];
    const cW = [0.5 + C[0], 0.5 + C[1]];
    symD = Math.min(symD, segDist(p, aW, fW) - STEM_W);
    symD = Math.min(symD, segDist(p, fW, bW) - STEM_W);
    symD = Math.min(symD, segDist(p, fW, cW) - STEM_W);

    const symMask = 1 - smooth(-aa, aa, symD);
    if (symMask > 0) {
      // 略微冷白偏紫，避免死白
      const ink = mix(C_WHITE, [0xe9, 0xe6, 0xff], 0.28);
      color = mix(color, ink, symMask);
    }

    const i = (y * S + x) * 3;
    px[i] = color[0];
    px[i + 1] = color[1];
    px[i + 2] = color[2];
  }
}

// ---- 最小 PNG 编码 ----
const crcTable = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, crc]);
};

const rgb = Buffer.alloc(S * S * 3);
for (let i = 0; i < S * S * 3; i++) rgb[i] = Math.round(clamp01(px[i] / 255) * 255);

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(S, 0);
ihdr.writeUInt32BE(S, 4);
ihdr[8] = 8;
ihdr[9] = 2; // RGB

const raw = Buffer.alloc(S * (S * 3 + 1));
for (let y = 0; y < S; y++) {
  raw[y * (S * 3 + 1)] = 0;
  rgb.copy(raw, y * (S * 3 + 1) + 1, y * S * 3, (y + 1) * S * 3);
}

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);

const outDir = path.join(__dirname, '..', 'GitVault', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset');
fs.mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, 'AppIcon.png');
fs.writeFileSync(outPath, png);
console.log('icon v2 written:', outPath, png.length, 'bytes');
