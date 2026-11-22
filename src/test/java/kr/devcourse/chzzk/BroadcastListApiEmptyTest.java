package kr.devcourse.chzzk;

import static org.assertj.core.api.Assertions.assertThat;

import com.jayway.jsonpath.JsonPath;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/** 방송이 하나도 없는 서버(자기 데이터 디렉터리)에서 GET /api/broadcasts 는 두 목록을 빈 배열로 준다. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class BroadcastListApiEmptyTest {

    @TempDir
    static Path dataDir;

    @DynamicPropertySource
    static void dataDir(DynamicPropertyRegistry registry) {
        registry.add("chzzk.data-dir", dataDir::toString);
    }

    @LocalServerPort
    int port;

    @Test
    void 방송이_없으면_비로그인으로_200이고_두_목록이_빈_배열이다() throws Exception {
        var response = TestLogin.Http.anonymous(port).get("/api/broadcasts");

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.headers().firstValue("Content-Type")).hasValueSatisfying(
                type -> assertThat(type).startsWith("application/json"));
        assertThat((List<?>) JsonPath.read(response.body(), "$.live")).isEmpty();
        assertThat((List<?>) JsonPath.read(response.body(), "$.recorded")).isEmpty();
    }
}
