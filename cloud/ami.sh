#!/bin/bash

[ "X$1" == "X" ] && echo "Name needed" && exit 1
[ "X`which ec2-bundle-vol`" == "X" ] && echo "AMI Tools needed" && exit 1
[ "X`which ec2-register`" == "X" ] && echo "API Tools needed" && exit 1
[ "X`which s3cmd`" == "X" ] && echo "s3cmd needed" && exit 1
arch=i386

rm -rf /mnt/image*
ec2-bundle-vol -r $arch --prefix "${1}" -d /mnt --user 523098207170 -k /root/ec2/pk-FU5GN7L66JNY23WFULSUXN4QKMAR2KJ4.pem -c /root/ec2/cert-FU5GN7L66JNY23WFULSUXN4QKMAR2KJ4.pem -e /usr/portage/distfiles
ec2-upload-bundle -b igorsimonov.com -m /mnt/"${1}".manifest.xml -a $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY
ec2-register --region eu-west-1 igorsimonov.com/"${1}".manifest.xml -n "${1}"

