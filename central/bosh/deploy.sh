#!/bin/bash -xe
export projectid=vic-goog
export region=us-central1
export zone=us-central1-f

gcloud config set project ${projectid}
gcloud config set compute/zone ${zone}
gcloud config set compute/region ${region}

CRED_FILE=/tmp/terraform-bosh.key.json
if [ ! -f "$CRED_FILE" ]
then
  gcloud iam service-accounts keys create $CRED_FILE \
    --iam-account terraform-bosh@${projectid}.iam.gserviceaccount.com
fi

export GOOGLE_CREDENTIALS=$(cat $CRED_FILE)

terraform plan -var projectid=${projectid} -var region=${region} -var zone=${zone}
terraform apply -var projectid=${projectid} -var region=${region} -var zone=${zone}
