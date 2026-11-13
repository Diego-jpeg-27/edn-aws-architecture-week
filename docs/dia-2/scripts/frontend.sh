#!/bin/bash
# User data do Launch Template de frontend (Dia 2).
# A URL da fila vem do Parameter Store. Antes de usar, substitua <SUA_REGIAO> e <NOME>.
set -e

yum update -y --security
yum install -y python3 python3-pip
pip3 install flask boto3

mkdir -p /opt/frontend-app

cat > /opt/frontend-app/app.py << 'EOF'
import json
import boto3
from datetime import datetime, timezone
from flask import Flask, request, render_template_string
import uuid

app = Flask(__name__)

# Exemplo de região: 'us-west-1'
ssm = boto3.client('ssm', region_name='<SUA_REGIAO>')

def get_parameter(name):
    return ssm.get_parameter(Name=name, WithDecryption=True)['Parameter']['Value']

# Exemplo de <NOME>: 'mariosilva' (o mesmo usado ao criar os parâmetros)
region = get_parameter('/projeto/<NOME>/region')
QUEUE_URL = get_parameter('/projeto/<NOME>/sqs/queue-url')

sqs_client = boto3.client('sqs', region_name=region)

HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Semana de Arquitetura AWS | Escola da Nuvem</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;600&display=swap" rel="stylesheet">
    <style>
        :root { --navy: #00102e; --cyan: #19c3d6; --sky: #3aa6e8; --paper: #f3f6fa; --ink: #0d1b33; --muted: #4c5a73; }
        * { box-sizing: border-box; }
        body { margin: 0; background: var(--paper); color: var(--ink); font: 16px/1.55 system-ui, "Segoe UI", Roboto, sans-serif; }
        a:focus-visible, input:focus-visible, button:focus-visible { outline: 3px solid var(--cyan); outline-offset: 2px; }
        .wrap { max-width: 880px; margin: 0 auto; padding: 0 24px; }

        .hero { background: var(--navy); color: #fff; padding: 32px 0 56px; overflow: hidden; }
        .top { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; }
        .site { color: #fff; font-size: 15px; text-decoration: none; border-bottom: 1px solid var(--cyan); padding-bottom: 2px; }
        .site:hover { color: var(--cyan); }

        .logo { position: relative; display: inline-block; font: 600 30px/0.95 Sora, sans-serif; letter-spacing: -0.02em; }
        .logo span { display: block; }
        .logo { padding-right: 34px; }
        .logo svg { position: absolute; left: 42px; top: 20px; width: 96px; height: 62px; overflow: visible; }
        .cloud { fill: none; stroke: url(#g); stroke-width: 6; stroke-linecap: round; stroke-dasharray: 1; stroke-dashoffset: 1; animation: draw 1.6s cubic-bezier(.6,0,.2,1) .3s forwards; }
        .dot { font-style: normal; color: var(--cyan); opacity: 0; animation: pop .3s ease-out 1.8s forwards; }
        @keyframes draw { to { stroke-dashoffset: 0; } }
        @keyframes pop { to { opacity: 1; } }

        .hero h1 { font: 600 clamp(32px, 6vw, 52px)/1.08 Sora, sans-serif; letter-spacing: -0.03em; margin: 56px 0 12px; max-width: 14ch; }
        .hero p { margin: 0; max-width: 52ch; color: #b9c6e4; }

        main.wrap { padding-top: 40px; padding-bottom: 64px; }
        h2 { font: 600 20px/1.3 Sora, sans-serif; margin: 0 0 4px; }
        .hint { margin: 0 0 20px; color: var(--muted); }
        label { display: block; font-weight: 600; margin-bottom: 6px; }
        .row { display: flex; gap: 10px; flex-wrap: wrap; }
        input[type="text"] { flex: 1 1 280px; padding: 12px 14px; font-size: 16px; color: var(--ink); background: #fff; border: 1.5px solid #c5cfdf; border-radius: 6px; }
        input[type="text"]:hover { border-color: var(--sky); }
        button { padding: 12px 22px; font: 600 16px Sora, sans-serif; color: var(--navy); background: var(--cyan); border: 0; border-radius: 6px; cursor: pointer; }
        button:hover { background: #4fd3e2; }
        .message { margin-top: 20px; padding: 12px 14px; border-left: 4px solid; background: #fff; word-break: break-word; }
        .success { border-color: #1f9d55; color: #155c34; }
        .error { border-color: #c53030; color: #8a1f1f; }

        @media (prefers-reduced-motion: reduce) { .cloud, .dot { animation: none; stroke-dashoffset: 0; opacity: 1; } }
    </style>
</head>
<body>
    <header class="hero">
        <div class="wrap">
            <div class="top">
                <div class="logo" role="img" aria-label="Escola da Nuvem">
                    <span>escola</span><span>da</span><span>nuvem<i class="dot">.</i></span>
                    <svg viewBox="0 0 96 62" aria-hidden="true">
                        <defs><linearGradient id="g" x1="0" x2="1"><stop offset="0" stop-color="#19c3d6"/><stop offset="1" stop-color="#3aa6e8"/></linearGradient></defs>
                        <path class="cloud" pathLength="1" d="M18 40 A14 14 0 0 1 34 20 A22 22 0 0 1 74 24 A16 16 0 0 1 78 58"/>
                    </svg>
                </div>
                <a class="site" href="https://mkt.escoladanuvem.org/" target="_blank" rel="noopener">Conheça a Escola da Nuvem</a>
            </div>
            <h1>Semana de Arquitetura AWS</h1>
            <p>Envie um texto. O frontend o coloca na fila SQS, o backend lê a fila e grava o registro no DynamoDB.</p>
        </div>
    </header>
    <main class="wrap">
        <h2>Nova requisição</h2>
        <p class="hint">Qualquer texto serve para testar o fluxo completo.</p>
        <form method="POST" action="/submit">
            <label for="data">Texto</label>
            <div class="row">
                <input type="text" id="data" name="data" required placeholder="Ex.: teste do dia 2">
                <button type="submit">Enviar para a fila</button>
            </div>
        </form>
        {% if message %}
        <div class="message {{ message_type }}" role="status">{{ message }}</div>
        {% endif %}
    </main>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)

@app.route('/submit', methods=['POST'])
def submit():
    user_data = request.form.get('data', '')
    if not user_data:
        return render_template_string(HTML_TEMPLATE, message='Please enter some data', message_type='error')
    try:
        request_id = str(uuid.uuid4())
        message_body = {
            'requestId': request_id,
            'data': user_data,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }
        sqs_client.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(message_body))
        return render_template_string(HTML_TEMPLATE,
                                      message=f'Request submitted successfully! Request ID: {request_id}',
                                      message_type='success')
    except Exception as e:
        return render_template_string(HTML_TEMPLATE,
                                      message=f'Error submitting request: {str(e)}',
                                      message_type='error')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF

cat > /etc/systemd/system/frontend-app.service << 'EOF'
[Unit]
Description=Frontend Web Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/frontend-app
ExecStart=/usr/bin/python3 /opt/frontend-app/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frontend-app.service
# restart (e não start) para aplicar o novo app.py se o script rodar de novo numa instância existente
systemctl restart frontend-app.service

echo "Frontend application installed and started successfully"
