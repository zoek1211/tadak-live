import { describe, expect, it, vi } from "vitest";
import { openInApp, windowLabel, type WindowApi } from "../src/web";

function fakeApi(existing: string[] = []): WindowApi & { created: unknown[]; focused: string[]; browser: string[] } {
  const api = {
    created: [] as unknown[],
    focused: [] as string[],
    browser: [] as string[],
    async exists(label: string) {
      return existing.includes(label);
    },
    async focus(label: string) {
      api.focused.push(label);
    },
    async create(label: string, url: string, title: string) {
      api.created.push({ label, url, title });
    },
    async openInBrowser(url: string) {
      api.browser.push(url);
    },
  };
  return api;
}

describe("windowLabel", () => {
  it("웹 주소의 경로로 창 이름을 만든다(같은 화면은 같은 창)", () => {
    expect(windowLabel("https://tadak.example.test/live/3")).toBe("web-live-3");
    expect(windowLabel("https://tadak.example.test/broadcasts/12")).toBe("web-broadcasts-12");
    expect(windowLabel("https://tadak.example.test/")).toBe("web-home");
  });
});

describe("openInApp", () => {
  it("처음 여는 화면이면 앱 안 새 창을 만든다", async () => {
    const api = fakeApi();
    await openInApp("https://tadak.example.test/live/3", "저녁 산책 라이브", api);
    expect(api.created).toEqual([
      { label: "web-live-3", url: "https://tadak.example.test/live/3", title: "저녁 산책 라이브 · 타닥 라이브" },
    ]);
  });

  it("이미 열린 화면이면 새로 만들지 않고 그 창을 앞으로 가져온다", async () => {
    const api = fakeApi(["web-live-3"]);
    await openInApp("https://tadak.example.test/live/3", "저녁 산책 라이브", api);
    expect(api.created).toEqual([]);
    expect(api.focused).toEqual(["web-live-3"]);
  });

  it("앱 안 창을 만들지 못하면 기본 브라우저로 연다", async () => {
    const api = fakeApi();
    api.create = vi.fn(async () => {
      throw new Error("not allowed");
    });
    await openInApp("https://tadak.example.test/live/3", "라이브", api);
    expect(api.browser).toEqual(["https://tadak.example.test/live/3"]);
  });

  it("http(s) 주소가 아니면 열지 않는다", async () => {
    const api = fakeApi();
    await expect(openInApp("javascript:alert(1)", "x", api)).rejects.toThrow();
    expect(api.created).toEqual([]);
    expect(api.browser).toEqual([]);
  });
});
