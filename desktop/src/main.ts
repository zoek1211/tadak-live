/** 앱 진입점: 목록을 불러와 그리고, 30초마다·창이 다시 앞으로 올 때 새로 불러온다. */
import { ApiError, fetchBroadcasts } from "./api";
import { API_BASE } from "./config";
import { renderList, type ListHandlers, type ListState } from "./list";

export const APP_TITLE = "타닥 라이브";
const REFRESH_MS = 30_000;

let state: ListState = { kind: "loading" };
let loading = false;

const handlers: ListHandlers = {
  onOpenLive: () => {},
  onOpenRecorded: () => {},
  onRetry: () => void load(),
};

function root(): HTMLElement {
  return document.getElementById("app")!;
}

function render(): void {
  renderList(root(), state, handlers);
}

async function load(): Promise<void> {
  if (loading) return;
  loading = true;
  try {
    state = { kind: "ok", data: await fetchBroadcasts(API_BASE) };
  } catch (e) {
    // 이미 목록이 보이면 일시 오류로 화면을 지우지 않는다
    if (state.kind !== "ok") {
      state = { kind: "error", message: e instanceof ApiError ? e.message : "방송 목록을 불러오지 못했습니다." };
    }
  } finally {
    loading = false;
    render();
  }
}

function start(): void {
  document.title = APP_TITLE;
  render();
  void load();
  setInterval(() => void load(), REFRESH_MS);
  window.addEventListener("focus", () => void load());
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") void load();
  });
}

if (typeof window !== "undefined" && !import.meta.env.VITEST) {
  window.addEventListener("DOMContentLoaded", start);
}
