#!/bin/bash
# User data das instâncias de frontend (Dia 1).
# Antes de usar, substitua <SUA_REGIAO> e <URL_DA_FILA_SQS>.
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
sqs_client = boto3.client('sqs', region_name='<SUA_REGIAO>')

# Exemplo: 'https://sqs.us-west-1.amazonaws.com/1111111111/fila-registros-test'
QUEUE_URL = '<URL_DA_FILA_SQS>'

HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Frontend Web Application</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; background-color: #f5f5f5; }
        .container { background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        form { margin-top: 20px; }
        label { display: block; margin-bottom: 5px; color: #666; }
        input[type="text"] { width: 100%; padding: 10px; margin-bottom: 20px; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box; }
        button { width: 100%; padding: 12px; background-color: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
        button:hover { background-color: #0056b3; }
        .message { margin-top: 20px; padding: 15px; border-radius: 4px; text-align: center; }
        .success { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .error { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Frontend Web Application</h1>
        <p style="text-align: center; color: #666;">Submit data to process via SQS queue</p>
        <form method="POST" action="/submit">
            <label for="data">Enter your data:</label>
            <input type="text" id="data" name="data" required placeholder="Enter any text to process">
            <button type="submit">Submit Request</button>
        </form>
        {% if message %}
        <div class="message {{ message_type }}">{{ message }}</div>
        {% endif %}
    </div>
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
systemctl start frontend-app.service

echo "Frontend application installed and started successfully"
