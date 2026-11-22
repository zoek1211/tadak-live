/**
 * 서버 방송 목록 API 클라이언트(계약: 저장소 루트 SPEC-broadcast-api.md).
 * 응답에서 아는 필드만 골라 담는다. 서버가 필드를 더해도 무시하고, 필요한 필드가 없으면 ApiError.
 */

export type LiveStatus = "ON_AIR" | "ENDED";
export type VideoSource = "UPLOADED" | "EXTERNAL";

export interface LiveItem {
  id: number;
  title: string;
  ownerNickname: string | null;
  status: LiveStatus;
  startedAt: string;
  endedAt: string | null;
  viewerCount: number;
  viewerCapacity: number;
  watchUrl: string;
}

export interface RecordedItem {
  id: number;
  title: string;
  ownerNickname: string | null;
  registeredAt: string;
  videoSource: VideoSource;
  playbackUrl: string;
  watchUrl: string;
}

export interface BroadcastList {
  live: LiveItem[];
  recorded: RecordedItem[];
}

export class ApiError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ApiError";
  }
}

const BAD_SHAPE = "서버 응답 모양이 예상과 다릅니다. 앱을 최신 버전으로 바꿔 주세요.";

type Json = Record<string, unknown>;

function object(value: unknown): Json {
  if (typeof value !== "object" || value === null || Array.isArray(value)) throw new ApiError(BAD_SHAPE);
  return value as Json;
}

function array(value: unknown): unknown[] {
  if (!Array.isArray(value)) throw new ApiError(BAD_SHAPE);
  return value;
}

function str(o: Json, key: string): string {
  const v = o[key];
  if (typeof v !== "string") throw new ApiError(BAD_SHAPE);
  return v;
}

function strOrNull(o: Json, key: string): string | null {
  const v = o[key];
  if (v === null) return null;
  if (typeof v !== "string") throw new ApiError(BAD_SHAPE);
  return v;
}

function num(o: Json, key: string): number {
  const v = o[key];
  if (typeof v !== "number" || !Number.isFinite(v)) throw new ApiError(BAD_SHAPE);
  return v;
}

function oneOf<T extends string>(o: Json, key: string, allowed: readonly T[]): T {
  const v = str(o, key);
  if (!(allowed as readonly string[]).includes(v)) throw new ApiError(BAD_SHAPE);
  return v as T;
}

function live(value: unknown): LiveItem {
  const o = object(value);
  return {
    id: num(o, "id"),
    title: str(o, "title"),
    ownerNickname: strOrNull(o, "ownerNickname"),
    status: oneOf(o, "status", ["ON_AIR", "ENDED"] as const),
    startedAt: str(o, "startedAt"),
    endedAt: strOrNull(o, "endedAt"),
    viewerCount: num(o, "viewerCount"),
    viewerCapacity: num(o, "viewerCapacity"),
    watchUrl: str(o, "watchUrl"),
  };
}

function recorded(value: unknown): RecordedItem {
  const o = object(value);
  return {
    id: num(o, "id"),
    title: str(o, "title"),
    ownerNickname: strOrNull(o, "ownerNickname"),
    registeredAt: str(o, "registeredAt"),
    videoSource: oneOf(o, "videoSource", ["UPLOADED", "EXTERNAL"] as const),
    playbackUrl: str(o, "playbackUrl"),
    watchUrl: str(o, "watchUrl"),
  };
}

export function parseBroadcastList(value: unknown): BroadcastList {
  const o = object(value);
  return { live: array(o.live).map(live), recorded: array(o.recorded).map(recorded) };
}

export async function fetchBroadcasts(base: string, fetchImpl: typeof fetch = fetch): Promise<BroadcastList> {
  let response: Response;
  try {
    response = await fetchImpl(`${base}/api/broadcasts`, { headers: { Accept: "application/json" } });
  } catch {
    throw new ApiError("서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.");
  }
  if (!response.ok) {
    throw new ApiError(`방송 목록을 불러오지 못했습니다(${response.status}). 잠시 뒤 다시 시도해 주세요.`);
  }
  let json: unknown;
  try {
    json = await response.json();
  } catch {
    throw new ApiError(BAD_SHAPE);
  }
  return parseBroadcastList(json);
}
