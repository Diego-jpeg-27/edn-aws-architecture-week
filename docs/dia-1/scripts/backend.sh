#!/bin/bash
# User data das instâncias de backend (Dia 1).
# Antes de usar, substitua <SUA_REGIAO>, <URL_DA_FILA_SQS> e <NOME_DA_TABELA_DYNAMODB>.
set -e

yum update -y --security
yum install -y python3 python3-pip
pip3 install boto3

mkdir -p /opt/backend-worker

cat > /opt/backend-worker/worker.py << 'EOF'
import boto3
import json
import time
from datetime import datetime, timezone

# Exemplo de região: 'us-west-1'
sqs = boto3.client('sqs', region_name='<SUA_REGIAO>')
dynamodb = boto3.resource('dynamodb', region_name='<SUA_REGIAO>')

# Exemplo: 'https://sqs.us-west-1.amazonaws.com/1111111111/fila-registros-nome-exemplo'
QUEUE_URL = '<URL_DA_FILA_SQS>'
# Exemplo: 'tabela-registros-nome-sobrenome'
TABLE_NAME = '<NOME_DA_TABELA_DYNAMODB>'

table = dynamodb.Table(TABLE_NAME)

def process_message(message_body):
    print(f"Processing message with requestId: {message_body['requestId']}")
    item = {
        'requestId': message_body['requestId'],
        'data': message_body['data'],
        'processedAt': datetime.now(timezone.utc).isoformat(),
        'status': 'processed'
    }
    table.put_item(Item=item)
    print(f"Successfully stored item in DynamoDB for requestId: {message_body['requestId']}")

def poll_queue():
    print(f"Starting worker - polling queue: {QUEUE_URL}")
    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20,
                VisibilityTimeout=30
            )
            if 'Messages' in response:
                for message in response['Messages']:
                    message_body = json.loads(message['Body'])
                    process_message(message_body)
                    # Só remove da fila após gravar com sucesso no DynamoDB
                    sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=message['ReceiptHandle'])
                    print(f"Message deleted from queue: {message['MessageId']}")
            else:
                print("No messages available")
        except Exception as e:
            print(f"Error processing message: {str(e)}")
            time.sleep(5)

if __name__ == '__main__':
    poll_queue()
EOF

cat > /etc/systemd/system/backend-worker.service << 'EOF'
[Unit]
Description=Backend Worker Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/backend-worker
ExecStart=/usr/bin/python3 /opt/backend-worker/worker.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable backend-worker.service
systemctl start backend-worker.service

echo "Backend worker application installed and started successfully"
