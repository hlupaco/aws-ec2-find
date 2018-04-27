#!/bin/bash

#find EC2 resource

if [ "$#" -ne 1 ] ; then
  echo "Usage: $0 resource_id/IP/domain/privateIP"
  exit 1
fi

id="$1"

owner_id="725043218116"

aws_cmd="aws ec2"
next_cmds="jq '.'"

# TODO: Volume, Snapshot

jq_inst="jq '.Reservations[].Instances[]' "
jq_vol=" | jq '.Volumes[]'"
jq_snap=" | jq '.Snapshots[]'"

#https://stackoverflow.com/questions/28164849/using-jq-to-parse-and-display-multiple-fields-in-a-json-serially
#DONE: aws ec2 describe-instances --region=eu-west-1 --filters 'Name=ip-address,Values=300.300.300.300' | jq '.Reservations[].Instances[]' | jq '"ID: \(.InstanceId)", "IP: \(.PublicIpAddress)", "Type: \(.InstanceType)", (.Tags[] | "\(.Key): \(.Value)")' | tr -d '"'

if [ "$#" -ne 1 ] ; then
  echo "Usage: $0 resource_id/IP/domain/privateIP"
    exit 1
fi

out_inst="jq '\"ID: \(.InstanceId)\", \"IP: \(.PublicIpAddress)\", \"Type: \(.InstanceType)\", \"State: \(.State.Name)\", (.Tags[] | \"\(.Key): \(.Value)\")' "
out_inst+=' | tr -d \"'
#DONE: aws ec2 describe-volumes --region=eu-west-1 --volume-id=vol-02ff49acaae04e789 | jq '.Volumes[]' | jq '"ID: \(.VolumeId)", "Instance: \(.Attachments[].InstanceId)", "Size: \(.Size)", (.Tags[] | "\(.Key): \(.Value)")' | tr -d '"'
out_vol=" | jq '.'"
out_snap=" | "

out_string=""
aws_opts=""

if echo "${id}" | grep '^i-' >/dev/null ; then
  aws_cmd+=" describe-instances --instance-id=${id}"

  jq_base="${jq_inst}"
  out_string="${out_inst}"

elif echo "${id}" | grep '^vol-' >/dev/null ; then
  aws_cmd+=" describe-volumes --volume-id=${id}"
  #TODO

  out_string="${out_vol}"

elif echo "${id}" | grep '^snap-' >/dev/null ; then
  aws_cmd+=" describe-snapshots --owner=${owner_id} --snapshot-id=${id}"
  #TODO

  out_string="${out_snap}"

elif host "${id}" >/dev/null ; then

  if echo "${id}" | grep 'ec2-.*\.compute\.amazonaws\.com' >/dev/null ; then
    #PUBLIC DNS
    aws_cmd+=" describe-instances "

    next_cmds=" jq 'select(.PublicDnsName == \"${id}\")'"

  elif echo "${id}" | grep '[a-z]' >/dev/null ; then
    #CUSTOM DOMAIN
    aws_cmd+=" describe-instances "

    public_ip=$(host "${id}" | tail -n1 | sed 's/.* \([^ ]*\)$/\1/')
    aws_opts=" --filters 'Name=ip-address,Values=${public_ip}'"

  else
    #PUBLIC IP
    aws_cmd+=" describe-instances "

    public_ip="${id}"

    aws_opts=" --filters 'Name=ip-address,Values=${public_ip}'"
    #aws_opts=" --filters 'Name=private-ip-address,Values=${private_ip}'"

  fi

  jq_base="${jq_inst}"
  out_string="${out_inst}"

else
  echo "Cannot process identifier: ${id}"
  exit

fi


for reg in \
  $(aws ec2 describe-regions | jq '.Regions[].RegionName' | tr -d '"') ; do
#for reg in eu-west-1 ; do
  (
  output=$(eval "${aws_cmd} --region=${reg} ${aws_opts} | ${jq_base} | ${next_cmds} | ${out_string}")

  if [ -n "${output}" ] ; then
    echo "REGION: ${reg}"
    echo "${output}"
  fi
  ) &

done

wait


