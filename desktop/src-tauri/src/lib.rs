/// 타닥 라이브 데스크톱 앱. 화면 로직은 프런트엔드(TypeScript)에 있고, 여기서는 플러그인만 붙인다.
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .run(tauri::generate_context!())
        .expect("타닥 라이브 앱을 시작하지 못했습니다");
}
