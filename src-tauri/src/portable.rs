//! Optional Windows portable-data paths. Default installed behaviour stays unchanged.
//! Marker: portable.flag beside RapidOne.exe, or an explicit RAPIDONE_PORTABLE_ROOT.
//! This only controls RapidOne-owned paths; bundled third-party plugins may use
//! Tauri/Windows known folders independently and need their own portable support.

use std::path::PathBuf;

#[cfg(windows)]
pub fn root() -> Option<PathBuf> {
    if let Some(dir) = std::env::var_os("RAPIDONE_PORTABLE_ROOT").filter(|v| !v.is_empty()) {
        return Some(PathBuf::from(dir));
    }
    let exe = std::env::current_exe().ok()?;
    let dir = exe.parent()?;
    if dir.join("portable.flag").is_file() {
        Some(dir.join("Data"))
    } else {
        None
    }
}

#[cfg(not(windows))]
pub fn root() -> Option<PathBuf> {
    None
}

/// RapidOne presets and trained styles; leave Tauri's default path unchanged
/// for normal installed builds.
pub fn app_data_dir(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    if let Some(root) = root() {
        return Ok(root.join("Roaming").join("com.chriscork.rapidone"));
    }
    use tauri::Manager;
    app.path().app_data_dir().map_err(|e| e.to_string())
}

/// Lensfun's downloaded database updates.
pub fn app_local_data_dir(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    if let Some(root) = root() {
        return Ok(root.join("Local").join("com.chriscork.rapidone"));
    }
    use tauri::Manager;
    app.path().app_local_data_dir().map_err(|e| e.to_string())
}

/// Profiles selected by the user, separate from the app's install resources.
pub fn document_dir(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    if let Some(root) = root() {
        return Ok(root.join("Documents"));
    }
    use tauri::Manager;
    app.path().document_dir().map_err(|e| e.to_string())
}
