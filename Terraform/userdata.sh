#!/bin/bash

#!/bin/bash -ex

sudo apt-get update
sudo apt-get install nginx -y 
sudo ufw allow 'Nginx Full'
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl status nginx