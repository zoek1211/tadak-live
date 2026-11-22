/** 서버 주소: 빌드할 때 VITE_TADAK_API_BASE 로 정한다(기본 공개 서버). 끝의 / 는 뗀다. */
export const DEFAULT_API_BASE = "https://129-221-138-89.sslip.io";

export const API_BASE: string = (import.meta.env.VITE_TADAK_API_BASE || DEFAULT_API_BASE).replace(/\/+$/, "");
