import { describe, expect, it, vi } from "vitest";
import { renderHeaderActions } from "../src/header";

describe("renderHeaderActions", () => {
  it("상단에 로그인 버튼을 두고, 누르면 서버의 웹 로그인 화면을 연다", () => {
    const root = document.createElement("div");
    const openLogin = vi.fn();
    renderHeaderActions(root, "https://tadak.example.test", { openLogin });
    const login = [...root.querySelectorAll("button")].find((b) => b.textContent === "로그인")!;
    login.click();
    expect(openLogin).toHaveBeenCalledWith("https://tadak.example.test/login");
  });
});
