import { describe, expect, it, vi } from "vitest";
import { renderHeaderActions } from "../src/header";

function setup() {
  const root = document.createElement("div");
  const h = { openWeb: vi.fn() };
  renderHeaderActions(root, "https://tadak.example.test", h);
  const button = (text: string) => [...root.querySelectorAll("button")].find((b) => b.textContent === text)!;
  return { root, h, button };
}

describe("renderHeaderActions", () => {
  it("상단에 로그인·회원가입 버튼을 이 순서로 둔다", () => {
    const { root } = setup();
    expect([...root.querySelectorAll("button")].map((b) => b.textContent)).toEqual(["로그인", "회원가입"]);
  });

  it("로그인을 누르면 서버의 웹 로그인 화면을 연다", () => {
    const { h, button } = setup();
    button("로그인").click();
    expect(h.openWeb).toHaveBeenCalledWith("https://tadak.example.test/login", "로그인");
  });

  it("회원가입을 누르면 서버의 웹 회원가입 화면을 연다", () => {
    const { h, button } = setup();
    button("회원가입").click();
    expect(h.openWeb).toHaveBeenCalledWith("https://tadak.example.test/signup", "회원가입");
  });
});
