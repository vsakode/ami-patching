send_email () {

  subject="AMI TEST Weekly regression - $status : `date "+%d%b%y"`"
  to="abc@xyz.com"
  mail -s "$subject" $to < $TIME

}

cleanup () {

  rm -rf $AMI_TEST/scripts
  return 0

}

source_variables () {
AMI_TEST=/path/to/run/directory
if [ -d $AMI_TEST/scripts ]
then
        rm -rf $AMI_TEST/scripts
else
        mkdir $AMI_TEST/scripts
fi
capture_run=$AMI_TEST/logs/run_log_`date "+%d%b%y_%H:%M:%S"`.txt
touch $capture_run
TIME=$AMI_TEST/logs/main_`date "+%d%b%y_%H:%M:%S"`.txt
touch $TIME
}


sync_code () {
cp /your/workspace/dir/patch-ami.sh $AMI_TEST/scripts
cp /your/worksspace/dir/patch-ami-input $AMI_TEST/scripts
cp /your/workspace/dir/source-ec2.sh $AMI_TEST/scripts
}

start_ami_test () {
start_time=`date +%s`
. $AMI_TEST/scripts/source-ec2.sh
$AMI_TEST/scripts/path-ami.sh < $AMI_TEST/scripts/patch-ami-imput &> $capture_run
if [ $? -eq 0 ]
then
echo "*************" >> $capture_run
echo "TEST PASSED" >> $capture_run
echo "*************" >> $capture_run
status=PASSED
else
echo "*************" >> $capture_run
echo "TEST FAILED" >> $capture_run
echo "*************" >> $capture_run
status=FAILED
fi
end_time=`date +%s`
total_time=`expr $end_time - $start_time`
}

main () {
  source_variables
  sync_code
  start_ami_test
  echo "" >> $TIME
  echo "Total Run Time : `expr $total_time / 60` minutes" >> $TIME
  echo "" >> $TIME

  echo "##############################################################" >> $TIME
  echo "AMI TEST STDOUT" >> $TIME
  echo "##############################################################" >> $TIME
  cat $capture_run >> $TIME
  send_email
  cleanup

}
main

##done

