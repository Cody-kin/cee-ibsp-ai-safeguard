"""Regression tests. API requests are in-process; hardware/services are not started."""
import ast
import base64
import importlib
import os
import sys
from pathlib import Path
from types import SimpleNamespace
import pytest

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / '01_cloud_server_aegis_platform/backend'
EDGE = ROOT / '02_jetson_nano_ai_node'
IOS = ROOT / 'IOS app/AI-SafeGuard/AI-SafeGuard'

@pytest.fixture(scope='module')
def api(tmp_path_factory):
    from fastapi.testclient import TestClient
    tmp = tmp_path_factory.mktemp('api')
    previous = Path.cwd()
    os.environ.update(DATABASE_URL=f'sqlite:///{tmp}/test.db', SECRET_KEY='test-only-key-not-for-deployment', INITIAL_ADMIN_PASSWORD='local-test-password', ENABLE_BACKGROUND_TASKS='0', TELEGRAM_BOT_TOKEN='', TELEGRAM_CHAT_ID='')
    os.chdir(tmp)
    sys.path.insert(0, str(BACKEND))
    main = importlib.import_module('app.main')
    devices = importlib.import_module('app.routers.devices')
    for name in ('OTA_DIR','FRAME_DIR','CONFIG_DIR','HEARTBEAT_DIR','LORA_CMD_DIR'):
        directory = tmp / name
        directory.mkdir()
        setattr(devices, name, str(directory))
    main.init_db()
    client = TestClient(main.app)
    login = client.post('/api/v1/auth/login', data={'username':'admin','password':'local-test-password'})
    assert login.status_code == 200
    headers = {'Authorization': 'Bearer '+login.json()['access_token']}
    yield client, headers, tmp
    client.close()
    main.engine.dispose()
    os.chdir(previous)

@pytest.mark.parametrize('method,path,body',[
    ('put','/api/v1/devices/cam_0/config',{'fire':0}),
    ('post','/api/v1/devices/NANO-001/system_command',{'command':'STOP'}),
    ('delete','/api/v1/ota/files',None),
    ('post','/api/v1/lorawan/downlink',{'command':'SYS|STOP'}),
])
def test_admin_operations_reject_anonymous(api,method,path,body):
    c,_,_=api
    assert c.request(method,path,json=body).status_code == 401

def test_regular_user_cannot_control_devices(api):
    c,admin,_=api
    assert c.post('/api/v1/users',headers=admin,json={'username':'viewer','password':'viewer-password','role':'user'}).status_code == 200
    token=c.post('/api/v1/auth/login',data={'username':'viewer','password':'viewer-password'}).json()['access_token']
    assert c.post('/api/v1/devices/NANO-001/system_command',headers={'Authorization':'Bearer '+token},json={'command':'STOP'}).status_code == 403

def test_ios_user_payload_matches_backend(api):
    c,h,_=api
    source=(IOS/'AISafeGuardAPIClient.swift').read_text()
    assert '["username": account,' in source
    assert c.post('/api/v1/users',headers=h,json={'username':'ios-user','password':'password-for-test','role':'user'}).status_code == 200

def test_invalid_role_rejected(api):
    c,h,_=api
    assert c.post('/api/v1/users',headers=h,json={'username':'bad-role','password':'password','role':'super_admin'}).status_code == 422

def test_delete_missing_user_is_404(api):
    c,h,_=api
    assert c.delete('/api/v1/users/999999',headers=h).status_code == 404

@pytest.mark.parametrize('days',[-1,0,3651])
def test_invalid_retention_rejected(api,days):
    c,h,_=api
    assert c.post('/api/v1/settings',headers=h,json={'retention_days':days}).status_code == 422

def test_event_roundtrip_and_snapshot(api):
    c,h,_=api
    event={'device_id':'NANO-TEST','event_type':'ai_vision','event_name':'test fire','severity':'info','description':'Synthetic fixture'}
    assert c.post('/api/v1/events',data=event,files={'image':('fixture.jpg',b'\xff\xd8synthetic\xff\xd9','image/jpeg')}).status_code == 201
    events=c.get('/api/v1/events',headers=h).json()['data']
    row=next(e for e in events if e['event_name']=='test fire')
    assert row['has_image'] is True
    assert row['device_id']=='NANO-TEST'

@pytest.mark.parametrize('bad',['../outside','a/b','a\\b','..',''])
def test_event_path_validation(api,bad):
    c,_,_=api
    result=c.post('/api/v1/events',data={'device_id':bad,'event_type':'ai_vision','event_name':'test','severity':'info','description':'test'})
    assert result.status_code in (400,422)

def test_ota_upload_rejects_path_traversal(api):
    c,h,tmp=api
    assert c.post('/api/v1/ota/upload',headers=h,files={'file':('../outside.py',b'print(1)')}).status_code == 400
    assert not (tmp/'outside.py').exists()

def test_ota_admin_file_lifecycle(api):
    c,h,_=api
    assert c.post('/api/v1/ota/upload',headers=h,files={'file':('example.txt',b'fixture')}).status_code == 200
    assert c.get('/api/v1/ota/files/example.txt/content',headers=h).json()['content']=='fixture'
    assert c.delete('/api/v1/ota/files/example.txt',headers=h).status_code==200

def pure_functions(path,names):
    tree=ast.parse(path.read_text())
    chosen=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names]
    env={}
    exec(compile(ast.Module(body=chosen,type_ignores=[]),str(path),'exec'),env)
    return env

@pytest.mark.parametrize('config,expected',[(None,{'fire':.4,'smoke':.3}),({}, {'fire':0.,'smoke':0.}),({'fire':0.}, {'fire':0.,'smoke':0.}),({'fire':1.}, {'fire':1.,'smoke':0.})])
def test_explicit_camera_disable(config,expected):
    fn=pure_functions(EDGE/'main.py',{'build_allowed_tasks'})['build_allowed_tasks']
    net=SimpleNamespace(camera_configs={} if config is None else {'cam_0':config})
    assert fn(net,'cam_0',{'fire':.4,'smoke':.3})==expected

def test_serial_config_preserves_zero_and_one():
    tree=ast.parse((EDGE/'modules/comms_lora.py').read_text())
    cls=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='LoRaManager')
    methods=[n for n in cls.body if isinstance(n,ast.FunctionDef) and n.name=='_handle_cfg']
    env={'debug_log':lambda *_:None}
    exec(compile(ast.Module(body=methods,type_ignores=[]),'serial_subset','exec'),env)
    obj=SimpleNamespace(network=SimpleNamespace(camera_configs={}),labels_map=['fire','smoke','fall','hardhat','vest','smoking','phone'])
    env['_handle_cfg'](obj,'CFG|cam_0|0,1,0,0,0,0,0')
    assert obj.network.camera_configs['cam_0']==dict(zip(obj.labels_map,[0.,1.,0.,0.,0.,0.,0.]))

def test_lora_payload_contract():
    env=pure_functions(BACKEND/'app/routers/lorawan.py',{'parse_node2_payload','normalize_event_type'})
    parsed=env['parse_node2_payload']('voice_sos|SOS|critical|help|937|795')
    assert parsed['mq2']=='937' and parsed['mq3']=='795'
    assert parsed['description']=='help [Gas:795/937]'
    assert parsed['event_type']=='voice_sos'

def test_unsigned_ota_default_is_disabled(monkeypatch):
    tree=ast.parse((EDGE/'modules/comms_lora.py').read_text())
    cls=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='LoRaManager')
    fn=next(n for n in cls.body if isinstance(n,ast.FunctionDef) and n.name=='_execute_ota_script')
    env={'os':os,'debug_log':lambda *_:None}
    exec(compile(ast.Module(body=[fn],type_ignores=[]),'ota_subset','exec'),env)
    monkeypatch.delenv('ALLOW_UNSIGNED_OTA',raising=False)
    # Any path beyond the guard would require dependencies intentionally absent here.
    assert env['_execute_ota_script'](SimpleNamespace()) is None

def test_swift_login_escapes_reserved_form_characters():
    # Source contract only: native Swift execution still requires Xcode.
    assert '.alphanumerics' in (IOS/'AISafeGuardAPIClient.swift').read_text()
    assert 'addingPercentEncoding' in (IOS/'APIClient.swift').read_text()
