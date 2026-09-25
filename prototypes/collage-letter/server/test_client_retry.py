"""Real Godot HTTP client against fault-injected Waitress and an isolated database."""
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
from contextlib import closing
from app import Service, create_http_server


def run():
    with tempfile.TemporaryDirectory() as directory:
        service = Service(Path(directory)/'retry.sqlite3')
        counts = {}
        def faulty(env, respond):
            path = env['PATH_INFO']
            method = env['REQUEST_METHOD']
            raw = env['wsgi.input'].read(int(env.get('CONTENT_LENGTH') or 0))
            env['wsgi.input'] = io.BytesIO(raw)
            data = json.loads(raw) if raw else {}
            key = data.get('request_id') or data.get('name') or method+' '+path
            counts[key] = counts.get(key, 0)+1
            fail = path=='/test/unavailable' or data.get('name')=='fail-signup'
            if path=='/v1/me' and counts[key]==1:
                fail = True
            if fail:
                respond('503 Service Unavailable',[('Content-Type','application/json')])
                return [b'{"error":"injected transient failure"}']
            headers=[]
            body=list(service(env,lambda status, values: headers.append((status,values))))
            # The database commit succeeds but the first response is lost behind a proxy.
            if key=='retry-exact-request-001' and counts[key]==1:
                respond('503 Service Unavailable',[('Content-Type','application/json')])
                return [b'{"error":"response lost after commit"}']
            respond(*headers[0])
            return body
        server=create_http_server(faulty,port=0)
        thread=threading.Thread(target=server.run,daemon=True);thread.start()
        try:
            env=dict(os.environ,COLLAGE_TEST_URL=f'http://127.0.0.1:{server.effective_port}')
            root=Path(__file__).resolve().parent.parent
            engine=os.environ['GODOT_BIN']
            result=subprocess.run([engine,'--headless','--path',str(root),'--script','res://tests/network_retry.gd'],env=env,capture_output=True,text=True,timeout=45)
            print(result.stdout)
            assert result.returncode==0 and 'RETRY_CLIENT_PASS' in result.stdout, result.stderr
            assert counts['retry-exact-request-001']==2,counts
            assert counts['retry-exact-request-002']==1,counts
            assert counts['GET /v1/me']==2,counts
            assert counts['GET /test/unavailable']==3,counts
            assert counts['fail-signup']==1,counts
            with closing(service.connect()) as db:
                assert db.execute("SELECT COUNT(*) FROM letters WHERE author<>'station'").fetchone()[0]==1
            print('WAITRESS_RETRY_PASS: one committed letter, same ID, bounded retries and no repeated registration')
        finally:
            server.close();server.task_dispatcher.shutdown();thread.join(timeout=3)

if __name__=='__main__': run()
