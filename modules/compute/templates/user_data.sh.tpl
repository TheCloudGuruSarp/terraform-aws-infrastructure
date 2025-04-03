#!/bin/bash

# Update system packages
apt-get update
apt-get upgrade -y

# Install necessary packages
apt-get install -y \
  amazon-cloudwatch-agent \
  awscli \
  nginx \
  jq \
  python3-pip

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/${environment}/nginx/access.log",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/${environment}/nginx/error.log",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "/${environment}/syslog",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    },
    "append_dimensions": {
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
      "ImageId": "$${aws:ImageId}",
      "InstanceId": "$${aws:InstanceId}",
      "InstanceType": "$${aws:InstanceType}"
    }
  }
}
EOF

# Start CloudWatch agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Configure Nginx
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# Create a simple index page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>${environment} Environment</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
            color: #333;
            line-height: 1.6;
        }
        .container {
            width: 80%;
            margin: 0 auto;
            overflow: hidden;
            padding: 20px;
        }
        header {
            background: #50b3a2;
            color: white;
            padding: 20px 0;
            text-align: center;
        }
        footer {
            background: #333;
            color: white;
            text-align: center;
            padding: 10px;
            position: fixed;
            bottom: 0;
            width: 100%;
        }
    </style>
</head>
<body>
    <header>
        <div class="container">
            <h1>${environment} Environment</h1>
        </div>
    </header>
    <div class="container">
        <h2>Welcome to the ${environment} server!</h2>
        <p>This server is running in the ${environment} environment.</p>
        <p>Instance ID: <span id="instance-id">Loading...</span></p>
        <p>Availability Zone: <span id="availability-zone">Loading...</span></p>
    </div>
    <footer>
        <p>&copy; 2025 Infrastructure as Code Demo</p>
    </footer>
    <script>
        // Fetch instance metadata
        fetch('http://169.254.169.254/latest/dynamic/instance-identity/document')
            .then(response => response.json())
            .then(data => {
                document.getElementById('instance-id').textContent = data.instanceId;
                document.getElementById('availability-zone').textContent = data.availabilityZone;
            })
            .catch(error => {
                console.error('Error fetching instance metadata:', error);
                document.getElementById('instance-id').textContent = 'Error fetching data';
                document.getElementById('availability-zone').textContent = 'Error fetching data';
            });
    </script>
</body>
</html>
EOF

# Restart Nginx
systemctl restart nginx

# Tag the instance (for easier identification in the console)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION="${region}"

aws ec2 create-tags \
  --resources $INSTANCE_ID \
  --tags Key=Name,Value=${environment}-web-server \
  --region $REGION

echo "Initialization completed"