package kr.devcourse.chzzk.member;

import java.time.Duration;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;
import org.springframework.security.web.csrf.CsrfTokenRequestAttributeHandler;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * 세션 폼 로그인과 CSRF. 로그인이 필요한 화면(라이브 송출 화면, 녹화방송 등록·수정·삭제, 댓글 작성·수정·삭제)은
 * 비로그인 요청을 /login으로 보내고, 나머지는 공개다. 소유자·작성자 여부는 각 서비스가 검사한다(JSON·fetch 경로는
 * 컨트롤러가 401로 거절). CSRF는 모든 변경 요청에 켠다. CSRF 토큰은 쿠키(XSRF-TOKEN)에 두고 폼은 _csrf 필드, fetch는 X-XSRF-TOKEN 헤더로 보낸다.
 * WebSocket 시그널링 경로(/ws/**)는 CSRF 대상에서 뺀다.
 * 클라이언트용 공개 읽기 API(/api/**)만 다른 출처의 GET을 허용한다(CORS, 모든 출처, 쿠키 없음). 화면 경로는 CORS를 열지 않는다.
 */
@Configuration
class SecurityConfig {

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(apiCors()))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/live/new").authenticated()
                        // 녹화방송 관리: 로그인 필수(소유자 여부는 컨트롤러가 검사해 403)
                        .requestMatchers("/broadcasts/new", "/broadcasts/*/edit", "/broadcasts/*/delete").authenticated()
                        .requestMatchers(HttpMethod.POST, "/broadcasts").authenticated()
                        // 결제창이 후원자의 브라우저로 돌려보내는 화면: 로그인 필수(후원자 본인 여부는 서비스가 검사해 403)
                        .requestMatchers("/donations/success", "/donations/fail").authenticated()
                        .requestMatchers(HttpMethod.POST, "/broadcasts/*/comments", "/live/*/comments",
                                "/comments/*/edit", "/comments/*/delete").authenticated()
                        .anyRequest().permitAll())
                .csrf(csrf -> csrf
                        .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                        .csrfTokenRequestHandler(new CsrfTokenRequestAttributeHandler())
                        .ignoringRequestMatchers("/ws/**", "/donations/webhook"))
                .formLogin(form -> form
                        .loginPage("/login")
                        .defaultSuccessUrl("/")
                        .failureUrl("/login?error")
                        .permitAll())
                .logout(logout -> logout
                        .logoutUrl("/logout")
                        .logoutSuccessUrl("/")
                        .permitAll());
        return http.build();
    }

    /** /api/** 에만 적용: 데스크톱 앱 웹뷰(tauri://localhost 등) 같은 다른 출처의 GET. 자격 증명(쿠키)은 허용하지 않는다. */
    private static CorsConfigurationSource apiCors() {
        CorsConfiguration api = new CorsConfiguration();
        api.setAllowedOrigins(List.of(CorsConfiguration.ALL));
        api.setAllowedMethods(List.of(HttpMethod.GET.name()));
        api.setAllowCredentials(false);
        api.setMaxAge(Duration.ofHours(1));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", api);
        return source;
    }
}
