# API 原始碼索引

由活動 app/main.py 及 app/routers 的路由裝飾器靜態抽取。路徑是局部宣告，router include prefix（通常 /api/v1）須配合main.py閱讀；不代表每個端點已驗證或授權完善。管理操作的測試與剩餘公開端點見REVIEW與TESTING。根目錄歷史main.py不屬此索引。

| 方法 | 宣告路徑 | 檔案與行號 | handler |
| --- | --- | --- | --- |
| POST | `/api/v1/auth/register` | `01_cloud_server_aegis_platform/backend/app/main.py:104` | `register_public` |
| POST | `/api/v1/auth/login` | `01_cloud_server_aegis_platform/backend/app/main.py:113` | `login` |
| GET | `/api/v1/settings` | `01_cloud_server_aegis_platform/backend/app/main.py:121` | `get_settings_api` |
| POST | `/api/v1/settings` | `01_cloud_server_aegis_platform/backend/app/main.py:125` | `update_settings_api` |
| POST | `/api/v1/events` | `01_cloud_server_aegis_platform/backend/app/main.py:132` | `create_event` |
| GET | `/api/v1/events` | `01_cloud_server_aegis_platform/backend/app/main.py:208` | `get_events` |
| POST | `/api/v1/events/reset` | `01_cloud_server_aegis_platform/backend/app/main.py:221` | `reset_safety_status` |
| DELETE | `/api/v1/events/clear` | `01_cloud_server_aegis_platform/backend/app/main.py:237` | `clear_all_events` |
| GET | `/current` | `01_cloud_server_aegis_platform/backend/app/routers/analysis.py:20` | `get_ai_analysis` |
| GET | `/qwen-insight` | `01_cloud_server_aegis_platform/backend/app/routers/analysis.py:35` | `get_qwen_insight` |
| POST | `/chat` | `01_cloud_server_aegis_platform/backend/app/routers/analysis.py:48` | `chat_with_ai` |
| POST | `/heartbeat` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:74` | `handle_heartbeat` |
| POST | `/stream/{device_id}/{camera_id}` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:100` | `upload_stream` |
| GET | `/stream/{device_id}/{camera_id}` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:113` | `get_stream` |
| GET | `/devices` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:125` | `list_devices` |
| PUT | `/devices/{camera_id}/config` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:151` | `update_device_config` |
| GET | `/lora/commands` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:158` | `get_lora_commands` |
| POST | `/devices/{device_id}/system_command` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:174` | `send_system_command` |
| POST | `/ota/upload` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:183` | `upload_ota_file` |
| GET | `/ota/files` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:191` | `list_ota_files` |
| DELETE | `/ota/files/{filename}` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:204` | `delete_ota_file` |
| GET | `/ota/files/{filename}/content` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:213` | `get_ota_file_content` |
| DELETE | `/ota/files` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:222` | `clear_all_ota_files` |
| GET | `/ota/{filename}` | `01_cloud_server_aegis_platform/backend/app/routers/devices.py:231` | `download_ota_file` |
| POST | `/lorawan/uplink` | `01_cloud_server_aegis_platform/backend/app/routers/lorawan.py:300` | `lorawan_uplink` |
| GET | `/lorawan/latest` | `01_cloud_server_aegis_platform/backend/app/routers/lorawan.py:342` | `lorawan_latest` |
| POST | `/lorawan/downlink` | `01_cloud_server_aegis_platform/backend/app/routers/lorawan.py:353` | `lorawan_downlink` |
| GET | `/lorawan/debug` | `01_cloud_server_aegis_platform/backend/app/routers/lorawan.py:372` | `lorawan_debug` |
| GET | `/settings` | `01_cloud_server_aegis_platform/backend/app/routers/settings.py:31` | `get_settings` |
| POST | `/settings` | `01_cloud_server_aegis_platform/backend/app/routers/settings.py:35` | `update_settings` |
| DELETE | `/events` | `01_cloud_server_aegis_platform/backend/app/routers/settings.py:41` | `clear_all_events` |
| GET | `/users` | `01_cloud_server_aegis_platform/backend/app/routers/settings.py:52` | `get_all_users` |
| DELETE | `/users/{user_id}` | `01_cloud_server_aegis_platform/backend/app/routers/settings.py:60` | `delete_user` |
| GET | `/me` | `01_cloud_server_aegis_platform/backend/app/routers/users.py:26` | `get_me` |
| PUT | `/me/password` | `01_cloud_server_aegis_platform/backend/app/routers/users.py:30` | `update_my_password` |
| GET | `` | `01_cloud_server_aegis_platform/backend/app/routers/users.py:36` | `get_all_users` |
| PUT | `/{user_id}` | `01_cloud_server_aegis_platform/backend/app/routers/users.py:43` | `update_user_info` |
| POST | `` | `01_cloud_server_aegis_platform/backend/app/routers/users.py:56` | `create_user` |
| DELETE | `/{user_id}` | `01_cloud_server_aegis_platform/backend/app/routers/users.py:67` | `delete_user` |
