package kr.devcourse.chzzk;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import java.nio.file.Path;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.web.context.WebApplicationContext;

/**
 * 데스크톱 앱 받기 페이지(GET /download): 비로그인 공개. 링크는 GitHub Releases 의 고정 이름 최신 파일(설정으로 앞부분을 바꿀 수 있음),
 * 지원 대상, 서명 없는 앱 경고 넘기는 법(macOS 그래도 열기·xattr, Windows 추가 정보 → 실행), 경고 이유, 휴대폰 안내.
 */
class DownloadPageWebTest {

    static final String DEFAULT_BASE = "https://github.com/zoek1211/tadak-live/releases/latest/download";

    @TempDir
    static Path dataDir;

    static String page(WebApplicationContext context) throws Exception {
        MvcResult result = TestWeb.mvc(context).perform(get("/download")).andReturn();
        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        return result.getResponse().getContentAsString();
    }

    @Nested
    @SpringBootTest
    class 기본_설정 {

        @DynamicPropertySource
        static void properties(DynamicPropertyRegistry registry) {
            registry.add("chzzk.data-dir", () -> dataDir.resolve("default").toString());
        }

        @Autowired
        WebApplicationContext context;

        @Test
        void 비로그인으로_열리고_제목이_앱_받기다() throws Exception {
            assertThat(page(context)).contains("<title>앱 받기 · 타닥 라이브</title>");
        }

        @Test
        void Windows와_macOS_받기_링크가_최신_Release_고정_주소다() throws Exception {
            String html = page(context);
            assertThat(html).contains("href=\"" + DEFAULT_BASE + "/Tadak-Live-windows-x64-setup.exe\"");
            assertThat(html).contains("href=\"" + DEFAULT_BASE + "/Tadak-Live-macos-universal.dmg\"");
        }

        @Test
        void 지원_대상과_파일_형식을_보여_준다() throws Exception {
            String html = page(context);
            assertThat(html).contains("Windows 10·11", "x64", "macOS 11 이상", "Apple Silicon", "Intel", ".exe", ".dmg");
        }

        @Test
        void 서명_없는_앱_경고를_넘기는_단계를_실제_화면_문구로_안내한다() throws Exception {
            String html = page(context);
            assertThat(html).contains("개인정보 보호 및 보안", "그래도 열기", "xattr -dr com.apple.quarantine");
            assertThat(html).contains("추가 정보", "실행");
            assertThat(html).doesNotContain("spctl");
        }

        @Test
        void 경고가_뜨는_이유와_모든_버전_링크가_있다() throws Exception {
            String html = page(context);
            assertThat(html).contains("코드 서명");
            assertThat(html).contains("href=\"https://github.com/zoek1211/tadak-live/releases\"");
        }

        @Test
        void 휴대폰은_브라우저로_쓰라고_안내한다() throws Exception {
            assertThat(page(context)).contains("iPhone", "Android", "브라우저");
        }

        @Test
        void 머리글_메뉴_맨_오른쪽에_앱_받기_링크가_있다_로그인_전() throws Exception {
            String html = TestWeb.mvc(context).perform(get("/broadcasts")).andReturn().getResponse().getContentAsString();
            String menu = html.substring(html.indexOf("header-actions"), html.indexOf("</nav>"));
            assertThat(menu).contains("href=\"/download\"");
            assertThat(menu.indexOf("앱 받기")).isGreaterThan(menu.indexOf("회원가입"));
        }

        @Test
        void 머리글_메뉴_맨_오른쪽에_앱_받기_링크가_있다_로그인_후() throws Exception {
            var mvc = TestWeb.mvc(context);
            var member = MemberSessions.signUpAs(mvc, "앱받기확인");
            String html = mvc.perform(get("/broadcasts").session(member)).andReturn().getResponse().getContentAsString();
            String menu = html.substring(html.indexOf("header-actions"), html.indexOf("</nav>"));
            assertThat(menu).contains("href=\"/download\"");
            assertThat(menu.indexOf("앱 받기")).isGreaterThan(menu.indexOf("로그아웃"));
        }

        @Test
        void OS_카드에_추천_표시용_표식과_스크립트가_있고_서버는_표시를_미리_붙이지_않는다() throws Exception {
            String html = page(context);
            assertThat(html).contains("data-os=\"windows\"", "data-os=\"mac\"", "이 컴퓨터용");
            assertThat(html).doesNotContain("download-card recommended");
        }
    }

    @Nested
    @SpringBootTest
    class 다운로드_주소_설정 {

        @DynamicPropertySource
        static void properties(DynamicPropertyRegistry registry) {
            registry.add("chzzk.data-dir", () -> dataDir.resolve("custom").toString());
            registry.add("chzzk.desktop.download-base", () -> "https://files.example.test/tadak/");
        }

        @Autowired
        WebApplicationContext context;

        @Test
        void 설정한_주소로_링크_앞부분이_바뀐다() throws Exception {
            String html = page(context);
            assertThat(html).contains("href=\"https://files.example.test/tadak/Tadak-Live-windows-x64-setup.exe\"");
            assertThat(html).contains("href=\"https://files.example.test/tadak/Tadak-Live-macos-universal.dmg\"");
        }
    }
}
