// Directed boundary pairs plus reproducible samples, independent of MoonBit.
export function integerCases(width) {
  const mask = (1n << BigInt(width)) - 1n;
  const sign = 1n << BigInt(width - 1);
  const pairs = [
    [0n, 0n], [0n, 1n], [1n, 0n], [mask, 1n], [mask, mask],
    [0n, mask], [sign - 1n, 1n], [sign, 1n], [sign, sign],
    [sign - 1n, sign], [mask, sign], [42n, 12n],
  ];
  let state = 0x6a09e667f3bcc909n;
  const next = () => {
    state = (state * 6364136223846793005n + 1442695040888963407n) & ((1n << 64n) - 1n);
    return state & mask;
  };
  for (let i = 0; i < 12; i++) pairs.push([next(), next()]);
  return pairs.map(([a, b], index) => ({a, b, shift: [0, 1, width - 1][index % 3]}));
}

// Include UTF-16 boundaries and SMT-LIB's highest code point (U+2FFFF).
const texts = ["", "abc", "A😀é", "日本語", "e\u0301", "\0\"\\", "\ud7ff\ue000\uffff", "\u{10000}\u{2ffff}", "\\u{41}"];
export const textCases = texts.flatMap(value => {
  const length = [...value].length;
  return [
    [-1, 1], [0, 0], [0, 1], [1, 2], [0, -1],
    [length, 1], [length - 1, 2147483647], [2147483647, 1],
  ].map(([start, count]) => ({value, start, count}));
});
