#!/bin/bash

yum install httpd -y
service httpd restart
chkconfig httpd on

echo "<h1><center>Terraform Sample Index.html</center></h1>" > /var/www/html/index.html
