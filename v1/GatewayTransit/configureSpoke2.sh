#!/bin/bash
sudo apt-get -o DPkg::Lock::Timeout=300 update -y
sudo apt-get -o DPkg::Lock::Timeout=300 install apache2 -y
sudo chmod -R -v 777 /var/www/
echo "<html><body style=\"background-color:blue;\"><h1 style=\"color:white;\">Hi from Spoke-2</h1></body></html>" > /var/www/html/index.html
sudo systemctl start apache2
sudo systemctl enable apache2
echo "Configuration done"
