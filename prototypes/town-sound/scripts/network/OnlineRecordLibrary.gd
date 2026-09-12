class_name OnlineRecordLibrary
extends RecordLibraryBase
## Phase 16 boundary: no backend is configured, so no requests are sent.
func list_records() -> Array[Dictionary]:
	last_error = "公共唱片库尚未配置。当前为 Local Mode，本地唱片可正常试听。"
	return []

func can_upload() -> bool:
	last_error = "公共唱片库暂时不可上传。作品已安全保存在本地。"
	return false
