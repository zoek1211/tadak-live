package kr.devcourse.chzzk.download;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * 데스크톱 앱 설치 파일 주소. 파일 이름은 데스크톱 빌드 워크플로(.github/workflows/desktop.yml)가 Release 에 올리는 고정 이름과 같다.
 * 주소 앞부분은 설정(chzzk.desktop.download-base)이고 기본값은 GitHub Releases 의 최신 파일 주소라, 새 Release 가 나와도 페이지를 고치지 않는다.
 */
@Component
public class DesktopDownloads {

    static final String WINDOWS_FILE = "Tadak-Live-windows-x64-setup.exe";
    static final String MACOS_FILE = "Tadak-Live-macos-universal.dmg";

    private final String base;
    private final String releasesPage;

    DesktopDownloads(@Value("${chzzk.desktop.download-base}") String base,
                     @Value("${chzzk.desktop.releases-page}") String releasesPage) {
        this.base = base.replaceAll("/+$", "");
        this.releasesPage = releasesPage;
    }

    public String windowsUrl() {
        return base + "/" + WINDOWS_FILE;
    }

    public String macosUrl() {
        return base + "/" + MACOS_FILE;
    }

    /** 모든 버전·변경 내역. */
    public String releasesPage() {
        return releasesPage;
    }
}
