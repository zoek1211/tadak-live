package kr.devcourse.chzzk;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * /api/** 만 다른 출처(데스크톱 앱 웹뷰, 예: tauri://localhost)의 GET을 허용한다. 공개 읽기 전용이라 모든 출처(*)를 허용하되
 * 쿠키(자격 증명)는 싣지 않는다. 화면 경로에는 CORS 헤더를 붙이지 않는다.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class BroadcastListApiCorsTest {

    @TempDir
    static Path dataDir;

    @DynamicPropertySource
    static void dataDir(DynamicPropertyRegistry registry) {
        registry.add("chzzk.data-dir", dataDir::toString);
    }

    private static final HttpClient CLIENT = HttpClient.newHttpClient();
    private static final String ORIGIN = "tauri://localhost";

    @LocalServerPort
    int port;

    HttpResponse<String> send(String method, String path, String... headers) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .headers(headers)
                .method(method, HttpRequest.BodyPublishers.noBody())
                .build();
        return CLIENT.send(request, HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void 다른_출처의_GET에_모든_출처_허용_헤더를_주고_자격_증명은_허용하지_않는다() throws Exception {
        HttpResponse<String> response = send("GET", "/api/broadcasts", "Origin", ORIGIN);

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.headers().firstValue("Access-Control-Allow-Origin")).hasValue("*");
        assertThat(response.headers().firstValue("Access-Control-Allow-Credentials")).isEmpty();
    }

    @Test
    void 사전_요청도_통과한다() throws Exception {
        HttpResponse<String> response = send("OPTIONS", "/api/broadcasts",
                "Origin", ORIGIN, "Access-Control-Request-Method", "GET");

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.headers().firstValue("Access-Control-Allow-Origin")).hasValue("*");
        assertThat(response.headers().firstValue("Access-Control-Allow-Methods"))
                .hasValueSatisfying(methods -> assertThat(methods).contains("GET"));
    }

    @Test
    void 쓰기_메서드의_사전_요청은_거절한다() throws Exception {
        HttpResponse<String> response = send("OPTIONS", "/api/broadcasts",
                "Origin", ORIGIN, "Access-Control-Request-Method", "POST");

        assertThat(response.headers().firstValue("Access-Control-Allow-Origin")).isEmpty();
    }

    @Test
    void 화면_경로에는_CORS_헤더가_없다() throws Exception {
        HttpResponse<String> response = send("GET", "/broadcasts", "Origin", ORIGIN);

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.headers().firstValue("Access-Control-Allow-Origin")).isEmpty();
    }
}
