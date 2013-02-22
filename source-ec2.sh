#!/bin/sh
export EC2_HOME=/path/to/ec2-api-tools
alias east='setenv EC2_URL http://ec2.amazonaws.com'
alias west='setenv EC2_URL http://ec2.us-west-1.amazonaws.com'
alias eu='setenv EC2_URL http://ec2.eu-west-1.amazonaws.com'
alias asiapac='setenv EC2_URL http://ec2.ap-southeast-1.amazonaws.com'
export EC2_ACCESS_KEY=
export EC2_SECRET_ACCESS_KEY=
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/path/to/ec2-api-tools/bin:/path/to/ec2-ami-tools/bin
export EC2_PRIVATE_KEY=/path/to/pk-***************.pem
export EC2_CERT=/path/to/cert-*************.pem
export JAVA_HOME=/usr/bin/java-1.6.0_02
export BUCKET_NAME=
export AWS_ACCOUNT_NUMBER=
export ARCH=x86_64
export EC2_AMITOOL_HOME=/path/to/ec2-ami-tools

