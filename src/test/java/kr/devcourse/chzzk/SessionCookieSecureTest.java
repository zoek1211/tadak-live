package kr.devcourse.chzzk;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Path;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * 배포(Caddy 뒤 HTTP)에서는 CHZZK_COOKIE_SECURE=true 로 로그인 세션 쿠키에 Secure 를 붙인다.
 * 로컬 HTTP 실행(기본값)에서는 붙이지 않는다. 그렇지 않으면 브라우저가 http://localhost 에서 쿠키를 버린다.
 */
class SessionCookieSecureTest {

    @TempDir
    static Path dataDir;

    static String signUpSessionCookie(int port) throws Exception {
        TestLogin.Http anonymous = TestLogin.Http.anonymous(port);
        HttpResponse<String> response = anonymous.send(anonymous.request("/signup")
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(
                        "loginId=" + TestLogin.newLoginId() + "&password=password1&nickname=tester")));
        return response.headers().allValues("Set-Cookie").stream()
                .filter(c -> c.startsWith("JSESSIONID=")).findFirst().orElseThrow();
    }

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    class 배포_설정 {

        @DynamicPropertySource
        static void properties(DynamicPropertyRegistry registry) {
            registry.add("chzzk.data-dir", () -> dataDir.resolve("secure").toString());
            registry.add("CHZZK_COOKIE_SECURE", () -> "true");
        }

        @LocalServerPort
        int port;

        @Test
        void CHZZK_COOKIE_SECURE_가_true_면_로그인_세션_쿠키에_Secure_가_붙는다() throws Exception {
            assertThat(signUpSessionCookie(port)).containsIgnoringCase("; Secure");
        }
    }

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    class 기본_설정 {

        @DynamicPropertySource
        static void properties(DynamicPropertyRegistry registry) {
            registry.add("chzzk.data-dir", () -> dataDir.resolve("default").toString());
        }

        @LocalServerPort
        int port;

        @Test
        void 기본값이면_로그인_세션_쿠키에_Secure_가_없다() throws Exception {
            assertThat(signUpSessionCookie(port)).doesNotContainIgnoringCase("Secure");
        }
    }
}
