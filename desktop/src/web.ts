/**
 * 웹 화면(라이브 시청·로그인·댓글·장작 넣기)을 앱 안 새 창으로 연다. 같은 화면은 같은 창을 다시 앞으로 가져온다.
 * 원격 웹 창에는 앱 권한(Tauri IPC)이 없다(capabilities 는 로컬 main 창에만). 창을 못 만들면 기본 브라우저로 연다.
 */
import { getAllWebviewWindows, WebviewWindow } from "@tauri-apps/api/webviewWindow";
import { openUrl } from "@tauri-apps/plugin-opener";

export interface WindowApi {
  exists(label: string): Promise<boolean>;
  focus(label: string): Promise<void>;
  create(label: string, url: string, title: string): Promise<void>;
  openInBrowser(url: string): Promise<void>;
}

const APP_NAME = "타닥 라이브";

function webUrl(url: string): URL {
  const parsed = new URL(url);
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new Error("웹 주소가 아닙니다.");
  }
  return parsed;
}

/** 창 이름: 경로 기반(예: /live/3 → web-live-3). Tauri 창 이름에 쓸 수 있는 글자만 남긴다. */
export function windowLabel(url: string): string {
  const path = webUrl(url).pathname.replace(/^\/+|\/+$/g, "");
  return path ? `web-${path.replace(/[^a-zA-Z0-9]+/g, "-")}` : "web-home";
}

export async function openInApp(url: string, title: string, api: WindowApi = tauriWindows): Promise<void> {
  const href = webUrl(url).href;
  const label = windowLabel(href);
  if (await api.exists(label)) {
    await api.focus(label);
    return;
  }
  try {
    await api.create(label, href, `${title} · ${APP_NAME}`);
  } catch {
    await api.openInBrowser(href);
  }
}

export async function openInBrowser(url: string, api: WindowApi = tauriWindows): Promise<void> {
  await api.openInBrowser(webUrl(url).href);
}

export const tauriWindows: WindowApi = {
  async exists(label) {
    return (await getAllWebviewWindows()).some((w) => w.label === label);
  },
  async focus(label) {
    const w = (await getAllWebviewWindows()).find((x) => x.label === label);
    await w?.unminimize();
    await w?.setFocus();
  },
  create(label, url, title) {
    return new Promise((resolve, reject) => {
      const w = new WebviewWindow(label, { url, title, width: 1200, height: 820, minWidth: 600, minHeight: 480 });
      w.once("tauri://created", () => resolve());
      w.once("tauri://error", (e) => reject(new Error(String(e.payload))));
    });
  },
  openInBrowser(url) {
    return openUrl(url);
  },
};
