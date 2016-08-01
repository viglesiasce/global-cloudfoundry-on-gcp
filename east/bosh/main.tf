variable "region" {
    type = "string"
    default = "us-east1"
}

variable "zone" {
    type = "string"
    default = "us-east1-d"
}

provider "google" {
    project = "vic-goog"
    region = "${var.region}"
}

// Subnet for the BOSH director
resource "google_compute_subnetwork" "bosh-subnet-1" {
  name          = "bosh-${var.region}"
  ip_cidr_range = "10.1.0.0/24"
  network       = "projects/vic-goog/global/networks/cf"
}

// BOSH bastion host
resource "google_compute_instance" "bosh-bastion" {
  name         = "bosh-bastion-${var.region}"
  machine_type = "n1-standard-4"
  zone         = "${var.zone}"

  tags = ["bosh-bastion", "bosh-internal"]

  disk {
    image = "ubuntu-1404-trusty-v20160610"
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.bosh-subnet-1.name}"
    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<EOT
#!/bin/bash -xe
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh

apt-get update -y
apt-get upgrade -y
apt-get install -y build-essential zlibc zlib1g-dev git jq ruby ruby-dev openssl libxslt-dev libxml2-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev libsqlite3-dev sqlite3
gem install bosh_cli
curl -o /tmp/cf.tgz https://s3.amazonaws.com/go-cli/releases/v6.19.0/cf-cli_6.19.0_linux_x86-64.tgz
tar -zxvf /tmp/cf.tgz && mv cf /usr/bin/cf && chmod +x /usr/bin/cf
curl -o /usr/bin/bosh-init https://s3.amazonaws.com/bosh-init-artifacts/bosh-init-0.0.94-linux-amd64
chmod +x /usr/bin/bosh-init
git clone https://github.com/viglesiasce/global-cloudfoundry-on-gcp.git

ssh-keygen -f ~/.ssh/bosh -P ""
curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/sshKeys" -H "Metadata-Flavor: Google" > /tmp/sshKeys
echo >> /tmp/sshKeys
echo -n bosh: >> /tmp/sshKeys
cat ~/.ssh/bosh.pub | tr -d '\n' >> /tmp/sshKeys
echo >> /tmp/sshKeys
gcloud compute project-info add-metadata --metadata-from-file sshKeys=/tmp/sshKeys

pushd /global-cloudfoundry-on-gcp/east/bosh
  export HOME=/root/
  bosh-init deploy manifest.yml
  printf "admin\nadmin\n" | bosh target https://10.1.0.6:25555 micro-google
  bosh upload stemcell https://storage.googleapis.com/bosh-cpi-artifacts/light-bosh-stemcell-3262.2-google-kvm-ubuntu-trusty-go_agent.tgz
  bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-mysql-release?v=23
  bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/garden-linux-release?v=0.333.0
  bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/etcd-release?v=36
  bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/diego-release?v=0.1454.0
  bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-release?v=231
popd

pushd /global-cloudfoundry-on-gcp/east/cloudfoundry
  sed -i s#{{DIRECTOR_UUID}}#`bosh status --uuid 2>/dev/null`# cloudfoundry.yml
  bosh deployment cloudfoundry.yml
  echo yes | bosh deploy
  if [ $? -ne 0 ]; then
    # Try again in case it failed
    echo yes | bosh deploy
  fi

  export ADDRESS=`gcloud compute addresses list --format json cf-us-east1 | jq -r '.[0].address'`
  export DOMAIN=east.cf.gcp.solutions
  gcloud dns record-sets transaction start --zone=cf
  gcloud dns record-sets transaction add --zone=cf --name="*.$DOMAIN." --type=A --ttl=300 $ADDRESS
  gcloud dns record-sets transaction execute --zone=cf
  echo "$ADDRESS  api.$DOMAIN login.$DOMAIN" >> /etc/hosts
  curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
  mv cf /usr/local/bin
popd
EOT

  service_account {
    scopes = ["cloud-platform"]
  }
}
