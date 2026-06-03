// Compact, URL-safe (de)serialization of a custom puzzle for share links.
// Pure and DOM-free so it can be unit-tested directly.

export interface DecodedPuzzle {
  solution: boolean[][];
  title: string;
}

function toBase64Url(str: string): string {
  const bytes = new TextEncoder().encode(str);
  let bin = "";
  for (const byte of bytes) bin += String.fromCharCode(byte);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(s: string): string {
  const padded = s.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(padded);
  const bytes = Uint8Array.from(bin, (ch) => ch.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

/** Encode a solution grid + title into a short URL-safe token. */
export function encodePuzzle(solution: boolean[][], title: string): string {
  const h = solution.length;
  const w = h > 0 ? solution[0].length : 0;
  const bits = solution.flat().map((b) => (b ? "1" : "0")).join("");
  return toBase64Url(JSON.stringify({ w, h, t: title, b: bits }));
}

/** Decode a token back into a solution grid + title. Throws on malformed input. */
export function decodePuzzle(token: string): DecodedPuzzle {
  const obj = JSON.parse(fromBase64Url(token)) as {
    w?: unknown;
    h?: unknown;
    t?: unknown;
    b?: unknown;
  };
  const w = obj.w;
  const h = obj.h;
  const bits = obj.b;
  const title = typeof obj.t === "string" ? obj.t : "Shared Puzzle";
  if (typeof w !== "number" || typeof h !== "number" || typeof bits !== "string") {
    throw new Error("malformed puzzle token");
  }
  if (w <= 0 || h <= 0 || w > 30 || h > 30 || bits.length !== w * h) {
    throw new Error("invalid puzzle dimensions");
  }
  const solution: boolean[][] = [];
  for (let r = 0; r < h; r++) {
    const row: boolean[] = [];
    for (let c = 0; c < w; c++) row.push(bits[r * w + c] === "1");
    solution.push(row);
  }
  return { solution, title };
}
