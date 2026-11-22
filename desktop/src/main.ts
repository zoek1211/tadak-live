/** 앱 진입점: 목록을 불러와 그리고, 30초마다·창이 다시 앞으로 올 때 새로 불러온다. */
import "./fonts";
import { ApiError, fetchBroadcasts } from "./api";
import { API_BASE } from "./config";
import type { RecordedItem } from "./api";
import { renderList, type ListHandlers, type ListState } from "./list";
import { renderPlayer } from "./player";
import { openInApp, openInBrowser } from "./web";

export const APP_TITLE = "타닥 라이브";
const REFRESH_MS = 30_000;

let state: ListState = { kind: "loading" };
/** 지금 보는 녹화방송(없으면 목록 화면). 플레이어를 보는 동안 목록 새로 고침이 화면을 덮지 않는다. */
let playing: RecordedItem | null = null;
let loading = false;

const handlers: ListHandlers = {
  onOpenLive: (item) => void openInApp(item.watchUrl, item.title),
  onOpenLiveInBrowser: (item) => void openInBrowser(item.watchUrl),
  onOpenRecorded: (item) => {
    playing = item;
    render();
  },
  onRetry: () => void load(),
};

function root(): HTMLElement {
  return document.getElementById("app")!;
}

function render(): void {
  if (playing) {
    renderPlayer(root(), playing, {
      onBack: () => {
        playing = null;
        render();
      },
      onOpenWeb: (item) => void openInApp(item.watchUrl, item.title),
      onOpenInBrowser: (item) => void openInBrowser(item.watchUrl),
    });
    return;
  }
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
    if (!playing) render();
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
