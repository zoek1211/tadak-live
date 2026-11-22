package kr.devcourse.chzzk.download;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/** 데스크톱 앱 받기 안내(비로그인 공개). 설치 파일은 서버에 두지 않고 GitHub Releases 로 링크한다. 계약: SPEC-download-page.md */
@Controller
class DownloadController {

    private final DesktopDownloads downloads;

    DownloadController(DesktopDownloads downloads) {
        this.downloads = downloads;
    }

    @GetMapping("/download")
    String page(Model model) {
        model.addAttribute("downloads", downloads);
        return "download/index";
    }
}
