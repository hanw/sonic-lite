#!/bin/bash

sudo apt-get install -y python-dev python-pip git python-ply nfs-common buildbot-slave fontconfig libxft-dev strace
mkdir -p buildbot
scp hwang@xcloud1.cs.cornell.edu:~/buildbot/master/mygit.sh .
sudo pip install --upgrade buildbot-slave
curl https://storage.googleapis.com/git-repo-downloads/repo > repo
sudo mv repo /usr/local/bin/
sudo chmod 755 /usr/local/bin/repo
ssh-keygen
cat ~/.ssh/id_rsa.pub
git config --global user.email "hwang@cs.cornell.edu"
git config --global user.name "Han Wang"
sudo echo "xcloud1.cs.cornell.edu:/home/shared  /nfs   nfs      auto,noatime,nolock,bg,nfsvers=3,intr,tcp,actimeo=1800 0 0" >> /etc/fstab
sudo mkdir /nfs
sudo mount -a
sudo ln -sf /usr/lib/x86_64-linux-gnu/libgmp.so.10 /usr/lib/x86_64-linux-gnu/libgmp.so.3
