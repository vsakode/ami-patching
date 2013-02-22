#!/bin/sh
source source-ec2.sh
errorlog="/tmp/error.$$.log"
boot_inst="/tmp/boot_inst.$$"
mynew_ami_id="/tmp/mynew_ami_id.$$"
ssh_log="/tmp/ssh_$$.log"
new_ssh_log="/tmp/new_ssh_$$.log"
modifyme="/tmp/modify.sh"
function chk_err {
if [ $1 -ne 0 ]
then
echo "***********************************************************************************"
echo "Error occured"
echo "-----------------------------------------------------------------------------------"
cat $errorlog
echo "***********************************************************************************"
exit 1
fi
}


#echo "Enter the ami ID to boot"
read ami_id
ami_exists="`ec2-describe-images -a | grep "$ami_id" | cut -f 2`"

#echo $ami_exists
echo "Booting AMI $ami_id"
if [ "$ami_id" != "$ami_exists" ]
then
echo "AMI doesnot exist"
exit 1
fi
#echo "enter ssh key pair name (Required)"
read ssh_key_pair

#echo "enter the path for the ssh key pair on your local machine (Required)"
read ssh_key_path
if [ -e $ssh_key_path ]
then
        echo ""
else
        echo "SSH key  does not exist"
        echo "Existing"
        exit 1
fi

#echo "Enter the AKI ID (Optional : press enter to skip)"
read aki_id
if [ -n "$aki_id" ]
then
aki_exists="`ec2-describe-images -a | grep "$aki_id" | cut -f 2`" 2> $errorlog

#echo $ami_exists
if [ "$aki_id" != "$aki_exists" ]
then
echo "AKI doesnot exist"
exit 1
fi
fi

#echo "Enter the ARI ID (Optional : press enter to skip)"
read ari_id
if [ -n "$ari_id" ]
then
ari_exists="`ec2-describe-images -a | grep "$ari_id" | cut -f 2`" 2> $errorlog

#echo $ami_exists
if [ "$ari_id" != "$ari_exists" ]
then
echo "ARI doesnot exist"
exit 1
fi
fi
#echo "Enter the zone name (Required)"
read zone_id


#echo "Enter the instance type to boot the instance (ex: m1.large) (Required)"
read inst_type

if [ -z $aki_id ] && [ -z $ari_id  ]
then
ec2-run-instances $ami_id -z $zone_id -k $ssh_key_pair -t $inst_type 1> $boot_inst 2> $errorlog
chk_err $?
elif [ -n $aki_id ] && [ -z $ari_id  ]
then
ec2-run-instances $ami_id --kernel $aki_id -z $zone_id -k $ssh_key_pair -t $inst_type 1> $boot_inst 2> $errorlog
chk_err $?
else
ec2-run-instances $ami_id --kernel $aki_id --ramdisk $ari_id -z $zone_id -k $ssh_key_pair -t $inst_type 1> $boot_inst 2> $errorlog
chk_err $?
fi

instance_id="`cat $boot_inst | cut -f 2 | tail -1`"

echo "Bootup requested with Instance ID : $instance_id"
        echo""
        echo""

status=pending
declare -i count
count=600
echo "AMI not booted yet"
        while [ $count -gt 0 ]
        do
                status="`ec2-describe-instances | grep $instance_id | cut -f 6`" 2> $errorlog

                        if [ $status == "running" ]
                then
                        echo "AMI booted up successfully"
                         break
                else
                        echo "$count sec remaining to timeout....."
                        count=$count-20
                sleep 20
        fi
        done
         if [ $status == "pending" ]
        then
                "Unable to boot new ami $ami_id"
                exit
        fi
        echo""
        echo""

        sleep 20
        echo "Testing ssh connectivity"
        public_dns="`ec2-describe-instances | grep $instance_id | cut -f 4`" 2> $errorlog


        ssh -i $ssh_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no root@$public_dns uptime 1> $ssh_log 2> $errorlog &

        pid=`echo $!`
        sleep 10
        if [ -e $ssh_log ]
        then
                echo "AMI SSH ready"
                rm -rf $ssh_log

        else
                echo "##################################################"
                echo "Not able to SSH original AMI $ami_id"
                echo "##################################################"
                kill $pid
                exit 1
        fi
        #echo "$ssh_status"

        echo""
        echo""

        echo "Transfering private and certificate key"
        scp -i $ssh_key_path -o StrictHostKeyChecking=no $EC2_PRIVATE_KEY root@$public_dns:/tmp 2> $errorlog
        chk_err $?

        scp -i $ssh_key_path -o StrictHostKeyChecking=no $EC2_CERTIFICATE_KEY root@$public_dns:/tmp 2> $errorlog
        chk_err $?

        echo "Transfering extra rpms"
        read tar_path
        scp -i $ssh_key_path -o StrictHostKeyChecking=no $tar_path root@$public_dns:/tmp/ 2> $errorlog
        chk_err $?

        rpm_tar=`basename $tar_path`

        echo "done..."
        echo""
        echo""


        echo "Installing extra RPMs"
        ssh -i $ssh_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no -T root@$public_dns 2> $errorlog << EOL
mkdir /tmp/rpms
cd /tmp
tar -xzf $rpm_tar -C /tmp/rpms
rpm -Uvh /tmp/rpms/*.rpm --force --nodeps
EOL
        chk_err $?
        echo "Done..."
        echo""
        echo""

        echo "Installing EC2-ami tools"
         ssh -i $ssh_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no -T root@$public_dns 2> $errorlog << EOL
curl -o /tmp/ec2-ami-tools-1.3-53773.noarch.rpm http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools-1.3-53773.noarch.rpm
rpm -UvH /tmp/ec2-ami-tools-1.3-53773.noarch.rpm &> /dev/null
echo "done.."
EOL
        chk_err $?

        echo "done..."
        echo""


        echo "Transfering user script to modify the ami (provide absolute path)"
        read user_script
        #touch /tmp/modify.sh
        #chmod 777 /tmp/modify.sh
        cat $user_script > $modifyme
        scp -i $ssh_key_path -o StrictHostKeyChecking=no $modifyme root@$public_dns:/tmp 2> $errorlog
        chk_err $?
        echo "done...."
        echo "Modifing Services and RPMS"
        ssh -i $ssh_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no -T root@$public_dns 2> $errorlog << EOL
cd /tmp
chmod 777 modify.sh
./modify.sh
EOL
        chk_err $?
        echo "Done..."
        echo""
        echo""

        pkid=`basename $EC2_PRIVATE_KEY`
        certid=`basename $EC2_CERTIFICATE_KEY`
        echo "Now bundling the AMI"
        ssh -i $ssh_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no -T root@$public_dns 2> $errorlog << EOL
ec2-bundle-vol -k /tmp/$pkid -c /tmp/$certid -u $AWS_ACCOUNT_NUMBER -e /mnt,/tmp,/root/.ssh
EOL
        chk_err $?
        echo "done...."
        echo""
        echo""

        echo "uploading the Bundle"
        ssh -i $ssh_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no -T root@$public_dns 2> $errorlog << EOL
ec2-upload-bundle -b $BUCKET_NAME -m /tmp/image.manifest.xml -a $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY
EOL
        chk_err $?

        echo "Done..."
        #image_name=`date '+rhel_x86_64_%d%b%y'`
        echo "Registering the AMI"
       # echo "Enter the name for your AMI on cloud"
        read imagename
        echo""
        echo""
        image_name=""$imagename"_`date "+%d%b%y_%H%M"`"
        ec2-register -n $image_name -a $ARCH $BUCKET_NAME/image.manifest.xml  2> $errorlog 1> $mynew_ami_id
        chk_err $?
        new_ami_id=`cat $mynew_ami_id | cut -f 2`
        echo "AMI Registered with AMI-ID : $new_ami_id"
        echo ""
        echo "Image name : - $image_name"
        echo""
        echo""


        echo "Booting up the new ami $new_ami_id"
        ec2-run-instances $new_ami_id -z $zone_id -k $ssh_key_pair -t $inst_type 1> $boot_inst 2> $errorlog
        chk_err $?
        echo""

        new_instance_id="`cat $boot_inst | cut -f 2 | tail -1`" 2> $errorlog
        echo "AMI booting with Instance ID : $new_instance_id"
        echo""

        status=pending
        declare -i count
        count=600
        echo "AMI not booted yet"
        while [ $count -gt 0 ]
        do
                status="`ec2-describe-instances | grep $new_instance_id | cut -f 6`" 2> $errorlog
                if [ $status == "running" ]
                then
                        echo "AMI booted up successfully"
                        break
                else
                        echo "$count sec remaining to timeout....."
                       count=$count-20
                        sleep 20
                fi
        done

        if [ $status == "pending" ]
        then
                "Unable to boot new ami $new_ami_id"
                exit
        fi

        sleep 20
        new_public_dns="`ec2-describe-instances | grep $new_instance_id | cut -f 4`"

        ssh -i $ssh_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no root@$new_public_dns uptime 1> $new_ssh_log 2> $errorlog &
        new_pid=$!
        sleep 10
        if [ -e $new_ssh_log ]
        then
                echo "AMI SSH ready"
                rm -rf $new_ssh_log
        else
                echo "##################################################"
                echo "Not able to SSH newly created AMI $new_ami_id"
                echo "##################################################"
                kill $new_pid
                exit 1
        fi

        chk_err $?
        echo""

         echo "Terminating original instance..............."
        ec2-terminate-instances $instance_id  2> $errorlog
        chk_err $?

        echo "done...."
        chk_err $?
        echo ""
        echo ""
        echo "Terminating the new ami instance"
        ec2-terminate-instances $new_instance_id 2> $errorlog
        chk_err $?
        echo""
        echo "Deregistering the new ami"
        ec2-deregister  $new_ami_id  2> $errorlog
        chk_err $?
        echo""

        echo "Deleting ami parts from the 'ami-regression' bucket"
        echo ""
        s3cmd del --recursive --force s3://$BUCKET_NAME  2> $errorlog
        chk_err $?

        rm -f $errorlog
        rm -f $boot_inst
        rm -f $mynew_ami_id
        rm -f $ssh_log &> /dev/null
        rm -f $new_ssh_log &> /dev/null
        rm -f $modifyme
        echo "Done...."
        echo""

        echo "Test Completed..."

